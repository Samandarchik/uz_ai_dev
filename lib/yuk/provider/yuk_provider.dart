import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/order_socket.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/services/yuk_service.dart';

// Bitta item uchun lokal holat: olingan miqdor va jami summa.
typedef ItemPrice = ({double taken, double subtotal});

// Yuk keltiruvchi bosh ekrani uchun holat boshqaruvchi.
class YukProvider extends ChangeNotifier {
  final YukService _service = YukService();

  List<YukOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

  // Lokal narxlar: orderId -> productId -> {taken, subtotal}.
  // Buyurtma yuborilguncha shu yerda turadi.
  final Map<int, Map<int, ItemPrice>> _prices = {};

  // Qoralamani backendga saqlash uchun har bir buyurtma bo'yicha debounce timer.
  // Maydon o'zgargach darrov emas, ozgina kutib (so'nggi o'zgarishdan keyin)
  // bir marta saqlaymiz — har bosishda so'rov ketmasligi uchun.
  final Map<int, Timer> _draftTimers = {};
  static const Duration _draftDebounce = Duration(milliseconds: 700);

  // OFFLINE himoya: kiritilgan narxlar telefon xotirasiga (SharedPreferences)
  // DARHOL yoziladi. Internet o'chiq bo'lsa ham ilovani yopib qayta ochganda
  // qiymatlar tiklanadi; internet qaytganda backendga sinxronlanadi.
  final BaseStorage _storage = sl<BaseStorage>();
  static const String _draftsKey = 'yuk_price_drafts';
  // Internet o'chiq bo'lsa buyurtmalar ro'yxati ham ko'rinishi uchun oxirgi
  // muvaffaqiyatli ro'yxat lokal keshlanadi.
  static const String _ordersKey = 'yuk_orders_cache';

  // Hozir ko'rsatilayotgan ro'yxat internetdan emas, lokal keshdan olinganmi
  // (UI'da "offline" eslatmasi ko'rsatish uchun).
  bool isOffline = false;

  // Hozir yuborilayotgan buyurtma id (spinner uchun). null bo'lsa hech nima.
  int? submittingOrderId;

  // Hozir qaytarib olinayotgan buyurtma id (spinner uchun).
  int? revertingOrderId;

  // Buyurtma shu sessiyada qachon yuborilgani — "qaytarib olish" oynasi uchun.
  final Map<int, DateTime> _submittedAt = {};

  // Yuborilgandan keyin qaytarib olish mumkin bo'lgan vaqt oynasi.
  static const Duration undoWindow = Duration(seconds: 30);

  // Buyurtmani qaytarib olishgacha qolgan vaqt (0 bo'lsa muddat o'tgan).
  Duration undoRemaining(int orderId) {
    final t = _submittedAt[orderId];
    if (t == null) return Duration.zero;
    final left = undoWindow - DateTime.now().difference(t);
    return left.isNegative ? Duration.zero : left;
  }

  // Berilgan sklad_id ga tegishli buyurtmalar.
  // Hali yuborilmagan (kutilayotgan) buyurtmalar tepada, yuborilganlar pastda.
  List<YukOrder> ordersForSklad(int skladId) {
    final list = orders.where((o) => o.skladId == skladId).toList();
    // Narxlangan yoki omborchi qabul qilgan buyurtmalar — "tugagan" (pastda).
    bool isDone(YukOrder o) =>
        o.status == 'narxlandi' || o.status == 'qabul_qilindi';
    final pending = list.where((o) => !isDone(o)).toList();
    final done = list.where(isDone).toList();
    return [...pending, ...done];
  }

  Future<void> fetchOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      orders = await _service.fetchOrders();
      isOffline = false;
      // Ro'yxatni offline kesh uchun saqlaymiz.
      _persistOrders();
      // Yuborilgan buyurtmalarning eski lokal qoralamasini tozalaymiz.
      _pruneDoneDrafts();
      // Internet bor — kutib turgan lokal qoralamalarni backendga yuboramiz.
      unawaited(flushDrafts());
    } catch (e) {
      // Internet yo'q: oxirgi saqlangan ro'yxatni ko'rsatamiz (bo'lsa).
      final cached = _readCachedOrders();
      if (cached.isNotEmpty) {
        orders = cached;
        isOffline = true;
        _pruneDoneDrafts();
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Joriy ro'yxatni JSON sifatida lokal saqlash.
  void _persistOrders() {
    try {
      final data = orders.map((o) => o.toJson()).toList();
      _storage.putString(key: _ordersKey, value: jsonEncode(data));
    } catch (_) {
      // saqlanmasa ham ilova ishlayveradi.
    }
  }

  // Lokal keshdagi buyurtmalar (internet yo'q paytda).
  List<YukOrder> _readCachedOrders() {
    final raw = _storage.getString(key: _ordersKey);
    if (raw.isEmpty) return [];
    try {
      return parseYukOrders(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  // Bitta item holatini saqlash (olingan miqdor + jami summa).
  void setItemPrice(int orderId, int productId, double taken, double subtotal) {
    final map = _prices.putIfAbsent(orderId, () => {});
    map[productId] = (taken: taken, subtotal: subtotal);
    notifyListeners();
    // 1) Lokal xotiraga DARHOL yozamiz (offline'da ham yo'qolmaydi).
    _persistDrafts();
    // 2) Backendga qoralama sifatida (debounce bilan) yuboramiz.
    _scheduleDraftSave(orderId);
  }

  // ─────────────────────── Qoralama: lokal saqlash ───────────────────────

  // _prices ni JSON sifatida SharedPreferences'ga yozish.
  // Shakl: { "orderId": { "productId": {"taken":x,"subtotal":y} } }.
  void _persistDrafts() {
    final out = <String, dynamic>{};
    _prices.forEach((orderId, items) {
      if (items.isEmpty) return;
      final m = <String, dynamic>{};
      items.forEach((pid, v) {
        m['$pid'] = {'taken': v.taken, 'subtotal': v.subtotal};
      });
      out['$orderId'] = m;
    });
    // Fire-and-forget; xato bo'lsa ilova baribir ishlayveradi.
    _storage.putString(key: _draftsKey, value: jsonEncode(out));
  }

  // Ilova ochilganda lokal qoralamalarni _prices ga tiklaymiz. fetchOrders'dan
  // OLDIN chaqirilsa, kartalar maydonlarni shu qiymatlar bilan to'ldiradi.
  Future<void> loadDrafts() async {
    final raw = _storage.getString(key: _draftsKey);
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((orderKey, items) {
        final orderId = int.tryParse(orderKey.toString());
        if (orderId == null || items is! Map) return;
        final map = _prices.putIfAbsent(orderId, () => {});
        items.forEach((pidKey, v) {
          final pid = int.tryParse(pidKey.toString());
          if (pid == null || v is! Map) return;
          final taken = (v['taken'] as num?)?.toDouble() ?? 0;
          final subtotal = (v['subtotal'] as num?)?.toDouble() ?? 0;
          map[pid] = (taken: taken, subtotal: subtotal);
        });
      });
      notifyListeners();
    } catch (_) {
      // Buzuq JSON bo'lsa e'tiborsiz qoldiramiz.
    }
  }

  // Internet qaytganda barcha lokal qoralamalarni backendga yuboramiz
  // (best-effort). fetchOrders muvaffaqiyatli bo'lgach va socket ulanganда chaqiriladi.
  Future<void> flushDrafts() async {
    final ids = _prices.keys.toList();
    for (final orderId in ids) {
      await _saveDraft(orderId);
    }
  }

  // Buyurtma yuborilgan/qabul qilingan bo'lsa, uning lokal qoralamasini
  // tozalaymiz (eski qiymat ko'rinib qolmasligi uchun).
  void _pruneDoneDrafts() {
    var changed = false;
    for (final o in orders) {
      if ((o.status == 'narxlandi' || o.status == 'qabul_qilindi') &&
          _prices.containsKey(o.id)) {
        _prices.remove(o.id);
        _draftTimers.remove(o.id)?.cancel();
        changed = true;
      }
    }
    if (changed) _persistDrafts();
  }

  // So'nggi o'zgarishdan keyin _draftDebounce o'tgach qoralamani backendga
  // bir marta yuboradi. Xatolar jim e'tiborsiz qoldiriladi — bu best-effort
  // saqlash (asosiy yuborish baribir alohida "Yuborish" tugmasi bilan).
  void _scheduleDraftSave(int orderId) {
    _draftTimers[orderId]?.cancel();
    _draftTimers[orderId] = Timer(_draftDebounce, () {
      _draftTimers.remove(orderId);
      _saveDraft(orderId);
    });
  }

  Future<void> _saveDraft(int orderId) async {
    final map = _prices[orderId];
    if (map == null || map.isEmpty) return;
    try {
      final items = map.entries
          .map((e) => <String, dynamic>{
                'product_id': e.key,
                'taken': e.value.taken,
                'subtotal': e.value.subtotal,
              })
          .toList();
      await _service.saveDraft(orderId, items, orderTotal(orderId));
    } catch (_) {
      // Qoralama saqlanmasa ham UI ishlayveradi; jim e'tiborsiz qoldiramiz.
    }
  }

  // Boshlang'ich qiymatni notify'siz o'rnatish (initState'da chaqirish uchun).
  // Qaytarib olingan buyurtmaning oldingi qiymatlarini tiklash uchun ishlatiladi.
  void seedItemPrice(int orderId, int productId, double taken, double subtotal) {
    final map = _prices.putIfAbsent(orderId, () => {});
    map[productId] = (taken: taken, subtotal: subtotal);
  }

  // Bitta item holatini olish (yo'q bo'lsa null).
  ItemPrice? getItemPrice(int orderId, int productId) {
    return _prices[orderId]?[productId];
  }

  // Buyurtma uchun jami summa (barcha kiritilgan subtotal yig'indisi).
  double orderTotal(int orderId) {
    final map = _prices[orderId];
    if (map == null) return 0;
    var sum = 0.0;
    for (final v in map.values) {
      sum += v.subtotal;
    }
    return sum;
  }

  // Kamida bitta item narxlanganmi (yuborish tugmasi uchun).
  bool hasAnyPrice(int orderId) {
    final map = _prices[orderId];
    return map != null && map.isNotEmpty;
  }

  // Buyurtmaning hamma itemi narxlanganmi.
  bool isOrderFullyPriced(YukOrder order) {
    final map = _prices[order.id];
    if (map == null) return false;
    for (final item in order.items) {
      if (!map.containsKey(item.productId)) return false;
    }
    return order.items.isNotEmpty;
  }

  // Narxlangan buyurtmani backendga yuborish (omborga qaytarish).
  Future<bool> submitPrices(int orderId) async {
    final map = _prices[orderId];
    if (map == null || map.isEmpty) {
      errorMessage = 'Hech qanday narx kiritilmagan';
      notifyListeners();
      return false;
    }

    // Kutib turgan qoralama saqlash bo'lsa bekor qilamiz — endi yakuniy narx
    // yuborilmoqda.
    _draftTimers.remove(orderId)?.cancel();

    submittingOrderId = orderId;
    errorMessage = null;
    notifyListeners();

    try {
      final items = map.entries
          .map((e) => <String, dynamic>{
                'product_id': e.key,
                'taken': e.value.taken,
                'subtotal': e.value.subtotal,
              })
          .toList();
      final total = orderTotal(orderId);

      await _service.priceOrder(orderId, items, total);

      // Yuborilgach lokal narxni tozala (lokal xotiradan ham), "qaytarib olish"
      // vaqtini belgila va ro'yxatni yangila.
      _prices.remove(orderId);
      _persistDrafts();
      _submittedAt[orderId] = DateTime.now();
      submittingOrderId = null;
      await fetchOrders();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      submittingOrderId = null;
      notifyListeners();
      return false;
    }
  }

  // Yuborilgan buyurtmani qaytarib olish (qayta tahrirlanadigan holatga).
  Future<bool> revertOrder(int orderId) async {
    revertingOrderId = orderId;
    errorMessage = null;
    notifyListeners();

    try {
      await _service.revertOrder(orderId);
      _submittedAt.remove(orderId);
      revertingOrderId = null;
      await fetchOrders();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      revertingOrderId = null;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────── Real-time (WebSocket) ───────────────────────
  StreamSubscription<OrderSocketEvent>? _socketSub;

  // WebSocket'ga ulanib, buyurtma hodisalarini tinglaymiz. fetchOrders bilan
  // birga ishlaydi (u boshlang'ich sync, bu — real-time yangilanish).
  void connectSocket() {
    _socketSub ??= OrderSocket.instance.events.listen(_onSocketEvent);
    OrderSocket.instance.connect();
  }

  // Ekrandan chiqqanda yoki logout'da ulanishni uzamiz.
  void disconnectSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    OrderSocket.instance.disconnect();
  }

  // Kelgan hodisani orders'ga qo'llash: deleted -> o'chir, aks holda upsert.
  void _onSocketEvent(OrderSocketEvent event) {
    final id = event.order['id'];
    final orderId = (id is int) ? id : int.tryParse(id?.toString() ?? '');
    if (orderId == null) return;

    if (event.action == 'deleted') {
      orders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return;
    }

    final order = YukOrder.fromJson(event.order);
    final index = orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      orders[index] = order; // bor bo'lsa almashtir
    } else {
      orders.add(order); // yo'q bo'lsa qo'sh
    }
    // Socket'dan xabar keldi — demak online'miz.
    isOffline = false;
    // Buyurtma yuborilgan bo'lsa eski lokal qoralamani tozalaymiz.
    _pruneDoneDrafts();
    // Yangilangan ro'yxatni keshlaymiz.
    _persistOrders();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectSocket();
    for (final t in _draftTimers.values) {
      t.cancel();
    }
    _draftTimers.clear();
    super.dispose();
  }
}
