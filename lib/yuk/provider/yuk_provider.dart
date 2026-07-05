import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/order_socket.dart';
import 'package:uz_ai_dev/yuk/models/yuk_ledger_model.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/services/yuk_service.dart';

// Bitta item uchun lokal holat: olingan miqdor va jami summa.
typedef ItemPrice = ({double taken, double subtotal});

// Yuk keltiruvchi bosh ekrani uchun holat boshqaruvchi.
class YukProvider extends ChangeNotifier {
  final YukService _service = YukService();

  // Asosiy sahifa ro'yxati: backenddan ?status=pending bilan olinadi
  // (faqat hali yuborilmagan buyurtmalar + undo oynasi ochiq yuborilganlar).
  List<YukOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

  // Tarix ekrani ro'yxati: backenddan ?status=done bilan alohida olinadi.
  List<YukOrder> historyOrders = [];
  bool isHistoryLoading = false;
  String? historyError;

  // Profil ekrani: kunlik hisob daftari (ostatok/rasxod/prixod).
  // Backenddan kamayuvchi tartibda (eng yangi kun birinchi) keladi.
  List<YukLedgerDay> ledger = [];
  bool isLoadingLedger = false;
  String? ledgerError;

  // Lokal narxlar: orderId -> productId -> {taken, subtotal}.
  // Buyurtma yuborilguncha shu yerda turadi.
  final Map<int, Map<int, ItemPrice>> _prices = {};

  // Yuk keltiruvchi o'zi qo'shgan qo'shimcha yozuvlar (proche mahsulot /
  // rasxod xarajat): orderId -> ro'yxat. Buyurtma yuborilguncha faqat lokal
  // saqlanadi (draft endpointга yuborilmaydi), submit'da added_items sifatida ketadi.
  final Map<int, List<YukAddedItem>> _addedItems = {};

  // Buyurtmaga biriktirilgan rasm/video ro'yxati: orderId -> entrylar.
  // Entry — telefon xotirasidagi fayl yo'li YOKI serverdagi relativ URL
  // ('/static/...' bilan boshlanadi; qaytarib olingan buyurtmadan keladi).
  // Yuborishda lokal fayllar avval /yuk/upload'ga yuklanadi.
  final Map<int, List<String>> _attachments = {};

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
  // Qo'shilgan yozuvlar (proche/rasxod) uchun lokal saqlash kaliti.
  static const String _addedItemsKey = 'yuk_added_items_drafts';
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

  // Buyurtma "tugagan"mi — narxlangan yoki omborchi qabul qilgan.
  static bool _isDone(YukOrder o) =>
      o.status == 'narxlandi' || o.status == 'qabul_qilindi';

  // Asosiy sahifa: berilgan skladning FAQAT hali yuborilmagan buyurtmalari.
  // Endigina yuborilgani "qaytarib olish" oynasi (30 s) tugaguncha ko'rinib
  // turadi — undo tugmasi qo'l ostida bo'lishi uchun; keyin tarixga o'tadi.
  List<YukOrder> pendingForSklad(int skladId) {
    return orders
        .where((o) =>
            o.skladId == skladId &&
            (!_isDone(o) || undoRemaining(o.id) > Duration.zero))
        .toList();
  }

  // Tarix ekrani: berilgan skladning yuborilgan buyurtmalari, yangisi tepada.
  List<YukOrder> doneForSklad(int skladId) {
    final list =
        historyOrders.where((o) => o.skladId == skladId && _isDone(o)).toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a.created) ?? DateTime(2000);
      final db = DateTime.tryParse(b.created) ?? DateTime(2000);
      return db.compareTo(da);
    });
    return list;
  }

  Future<void> fetchOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Asosiy sahifa uchun faqat yuborilmaganlarni olamiz.
      final fetched = await _service.fetchOrders(status: 'pending');
      // Endigina yuborilgan (undo oynasi hali ochiq) buyurtmalar pending
      // ro'yxatida kelmaydi — "Qaytarib olish" tugmasi ko'rinib turishi uchun
      // ularni eski ro'yxatdan saqlab qolamiz.
      for (final o in orders) {
        if (_isDone(o) &&
            undoRemaining(o.id) > Duration.zero &&
            !fetched.any((f) => f.id == o.id)) {
          fetched.add(o);
        }
      }
      orders = fetched;
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

  // Tarix ekrani uchun yuborilgan buyurtmalarni backenddan olish
  // (?status=done). Ekran ochilganda va pull-to-refresh'da chaqiriladi.
  Future<void> fetchHistory() async {
    isHistoryLoading = true;
    historyError = null;
    notifyListeners();

    try {
      historyOrders = await _service.fetchOrders(status: 'done');
    } catch (e) {
      historyError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  // Ledger kamida bir marta yuklanganmi — socket hodisalarida jim yangilash
  // faqat shundan keyin yoqiladi (profil ochilmagan bo'lsa keraksiz so'rov yo'q).
  bool _ledgerLoadedOnce = false;
  Timer? _ledgerRefreshTimer;

  // Profil ekrani uchun kunlik hisob daftarini backenddan olish.
  // Ekran ochilganda va pull-to-refresh'da chaqiriladi.
  Future<void> fetchLedger() async {
    _ledgerLoadedOnce = true;
    isLoadingLedger = true;
    ledgerError = null;
    notifyListeners();

    try {
      ledger = await _service.fetchLedger();
    } catch (e) {
      ledgerError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingLedger = false;
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
  void setItemPrice(
    int orderId,
    int productId,
    double taken,
    double subtotal,
  ) {
    final map = _prices.putIfAbsent(orderId, () => {});
    map[productId] = (taken: taken, subtotal: subtotal);
    notifyListeners();
    // 1) Lokal xotiraga DARHOL yozamiz (offline'da ham yo'qolmaydi).
    _persistDrafts();
    // 2) Backendga qoralama sifatida (debounce bilan) yuboramiz.
    _scheduleDraftSave(orderId);
  }

  // ──────────── Qo'shilgan yozuvlar (proche mahsulot / rasxod) ────────────

  // Buyurtmaning qo'shilgan yozuvlari (ko'rsatish tartibida).
  List<YukAddedItem> addedItemsFor(int orderId) =>
      List.unmodifiable(_addedItems[orderId] ?? const []);

  void addAddedItem(int orderId, YukAddedItem item) {
    _addedItems.putIfAbsent(orderId, () => []).add(item);
    notifyListeners();
    _persistAddedItems();
    // Rasxod/proche qo'shilishi ham qoralama bilan backendga ketadi —
    // ledger'dagi Rasxod real time yangilanishi uchun.
    _scheduleDraftSave(orderId);
  }

  void removeAddedItem(int orderId, int index) {
    final list = _addedItems[orderId];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) _addedItems.remove(orderId);
    notifyListeners();
    _persistAddedItems();
    _scheduleDraftSave(orderId);
  }

  // Qo'shilgan proche mahsulotlar summasi (mahsulot jamiga kiradi).
  double addedProductsTotal(int orderId) {
    var sum = 0.0;
    for (final it in _addedItems[orderId] ?? const <YukAddedItem>[]) {
      if (it.isProche) sum += it.subtotal;
    }
    return sum;
  }

  // Qo'shilgan rasxod (xarajat) yozuvlari summasi (mahsulot jamiga KIRMAYDI).
  double addedExpensesTotal(int orderId) {
    var sum = 0.0;
    for (final it in _addedItems[orderId] ?? const <YukAddedItem>[]) {
      if (it.isRasxod) sum += it.subtotal;
    }
    return sum;
  }

  // _addedItems ni JSON sifatida SharedPreferences'ga yozish.
  // Shakl: { "orderId": [ {item_type,name,taken,subtotal}, ... ] }.
  void _persistAddedItems() {
    final out = <String, dynamic>{};
    _addedItems.forEach((orderId, items) {
      if (items.isEmpty) return;
      out['$orderId'] = items.map((e) => e.toJson()).toList();
    });
    _storage.putString(key: _addedItemsKey, value: jsonEncode(out));
  }

  // Lokal saqlangan qo'shilgan yozuvlarni tiklash (loadDrafts ichида chaqiriladi).
  void _loadAddedItems() {
    final raw = _storage.getString(key: _addedItemsKey);
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((orderKey, items) {
        final orderId = int.tryParse(orderKey.toString());
        if (orderId == null || items is! List) return;
        final list = _addedItems.putIfAbsent(orderId, () => []);
        for (final v in items) {
          if (v is Map) {
            list.add(YukAddedItem.fromJson(Map<String, dynamic>.from(v)));
          }
        }
      });
    } catch (_) {
      // Buzuq JSON bo'lsa e'tiborsiz qoldiramiz.
    }
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
        m['$pid'] = {
          'taken': v.taken,
          'subtotal': v.subtotal,
        };
      });
      out['$orderId'] = m;
    });
    // Fire-and-forget; xato bo'lsa ilova baribir ishlayveradi.
    _storage.putString(key: _draftsKey, value: jsonEncode(out));
  }

  // Ilova ochilganda lokal qoralamalarni _prices ga tiklaymiz. fetchOrders'dan
  // OLDIN chaqirilsa, kartalar maydonlarni shu qiymatlar bilan to'ldiradi.
  Future<void> loadDrafts() async {
    // Qo'shilgan yozuvlar (proche/rasxod) ham shu bosqichda tiklanadi.
    _loadAddedItems();
    final raw = _storage.getString(key: _draftsKey);
    if (raw.isEmpty) {
      if (_addedItems.isNotEmpty) notifyListeners();
      return;
    }
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
    var addedChanged = false;
    for (final o in orders) {
      if (o.status == 'narxlandi' || o.status == 'qabul_qilindi') {
        if (_prices.containsKey(o.id)) {
          _prices.remove(o.id);
          _draftTimers.remove(o.id)?.cancel();
          changed = true;
        }
        if (_addedItems.containsKey(o.id)) {
          _addedItems.remove(o.id);
          addedChanged = true;
        }
      }
    }
    if (changed) _persistDrafts();
    if (addedChanged) _persistAddedItems();
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
    final map = _prices[orderId] ?? const <int, ItemPrice>{};
    final added = _addedItems[orderId] ?? const <YukAddedItem>[];
    // Narx ham, qo'shilgan item ham bo'lmasa yuboradigan narsa yo'q.
    if (map.isEmpty && added.isEmpty) return;
    try {
      final items = map.entries
          .map((e) => <String, dynamic>{
                'product_id': e.key,
                'taken': e.value.taken,
                'subtotal': e.value.subtotal,
              })
          .toList();
      // Qo'shilgan proche/rasxod itemlar ham qoralamada ketadi — profil
      // ledger'idagi Rasxod real time yangilanadi (backend ularni idempotent
      // qayta yozadi, submit'dagi bilan bir xil shakl).
      await _service.saveDraft(
        orderId,
        items,
        _catalogTotal(orderId),
        addedItems: added.map((e) => e.toJson()).toList(),
      );
    } catch (_) {
      // Qoralama saqlanmasa ham UI ishlayveradi; jim e'tiborsiz qoldiramiz.
    }
  }

  // Boshlang'ich qiymatni notify'siz o'rnatish (initState'da chaqirish uchun).
  // Qaytarib olingan buyurtmaning oldingi qiymatlarini tiklash uchun ishlatiladi.
  void seedItemPrice(
    int orderId,
    int productId,
    double taken,
    double subtotal,
  ) {
    final map = _prices.putIfAbsent(orderId, () => {});
    map[productId] = (taken: taken, subtotal: subtotal);
  }

  // Bitta item holatini olish (yo'q bo'lsa null).
  ItemPrice? getItemPrice(int orderId, int productId) {
    return _prices[orderId]?[productId];
  }

  // Katalogdagi (buyurtmadagi) itemlar uchun kiritilgan subtotal yig'indisi.
  double _catalogTotal(int orderId) {
    final map = _prices[orderId];
    if (map == null) return 0;
    var sum = 0.0;
    for (final v in map.values) {
      sum += v.subtotal;
    }
    return sum;
  }

  // Buyurtma uchun MAHSULOT jami summasi: katalog narxlari + qo'shilgan
  // proche mahsulotlar. Rasxod (xarajat) bunga KIRMAYDI —
  // u addedExpensesTotal'da alohida.
  double orderTotal(int orderId) {
    return _catalogTotal(orderId) + addedProductsTotal(orderId);
  }

  // Kamida bitta item narxlanganmi yoki qo'shimcha yozuv qo'shilganmi
  // (yuborish tugmasi uchun).
  bool hasAnyPrice(int orderId) {
    final map = _prices[orderId];
    if (map != null && map.isNotEmpty) return true;
    final added = _addedItems[orderId];
    return added != null && added.isNotEmpty;
  }

  // ─────────────────── Biriktirmalar (rasm/video) ───────────────────

  // Entry serverdagi URL'mi (lokal fayl emas).
  static bool isRemoteAttachment(String entry) =>
      entry.startsWith('/static/') || entry.startsWith('http');

  // Buyurtmaning joriy biriktirmalari (ko'rsatish tartibida).
  List<String> attachmentsFor(int orderId) =>
      List.unmodifiable(_attachments[orderId] ?? const []);

  void addAttachments(int orderId, List<String> paths) {
    if (paths.isEmpty) return;
    final list = _attachments.putIfAbsent(orderId, () => []);
    for (final p in paths) {
      if (p.isNotEmpty && !list.contains(p)) list.add(p);
    }
    notifyListeners();
  }

  void removeAttachment(int orderId, String entry) {
    final list = _attachments[orderId];
    if (list == null) return;
    list.remove(entry);
    if (list.isEmpty) _attachments.remove(orderId);
    notifyListeners();
  }

  // Qaytarib olingan (yoki qoralamali) pending buyurtmaning serverda saqlangan
  // biriktirmalarini lokal ro'yxatga tiklash — qayta yuborishda yo'qolmasin.
  // Faqat lokal ro'yxat bo'sh bo'lsa (kiritilganini ustidan yozmaslik uchun).
  void seedAttachments(int orderId, List<String> urls) {
    if (urls.isEmpty || _attachments.containsKey(orderId)) return;
    _attachments[orderId] = List.of(urls);
  }

  // Qaytarib olingan pending buyurtmaning serverdan qaytgan proche/rasxod
  // itemlarini lokal qo'shilgan yozuvlarga tiklash — qayta yuborishda
  // yo'qolmasin. Faqat lokal ro'yxat bo'sh bo'lsa (ustidan yozmaslik uchun).
  void seedAddedItems(int orderId, List<YukOrderItem> items) {
    if (_addedItems.containsKey(orderId)) return;
    final list = <YukAddedItem>[
      for (final it in items)
        if (it.isProche || it.isRasxod)
          YukAddedItem(
            itemType: it.itemType,
            name: it.name,
            taken: it.taken,
            subtotal: it.subtotal,
          ),
    ];
    if (list.isEmpty) return;
    _addedItems[orderId] = list;
    _persistAddedItems();
  }

  // Narxlangan buyurtmani backendga yuborish (omborga qaytarish).
  Future<bool> submitPrices(int orderId) async {
    final map = _prices[orderId] ?? const <int, ItemPrice>{};
    final added = _addedItems[orderId] ?? const <YukAddedItem>[];
    if (map.isEmpty && added.isEmpty) {
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
      // Mahsulot jami (katalog + proche); rasxod totalga kirmaydi — backend
      // uni expenses_total sifatida alohida hisoblaydi.
      final total = orderTotal(orderId);

      // Avval biriktirilgan lokal fayllarni (rasm/video) serverga yuklaymiz;
      // serverda allaqachon bor URL'lar (qaytarib olingandan qolgan) o'z
      // holicha ketadi. Birortasi yuklanmasa — butun yuborish to'xtaydi.
      final attachmentUrls = <String>[];
      for (final entry in _attachments[orderId] ?? const <String>[]) {
        if (isRemoteAttachment(entry)) {
          attachmentUrls.add(entry);
        } else {
          attachmentUrls.add(await _service.uploadFile(entry));
        }
      }

      final updated = await _service.priceOrder(
        orderId,
        items,
        total,
        attachments: attachmentUrls,
        addedItems: added.map((e) => e.toJson()).toList(),
      );

      // Yuborilgach lokal narxni tozala (lokal xotiradan ham), "qaytarib olish"
      // vaqtini belgila va ro'yxatni yangila.
      _prices.remove(orderId);
      _addedItems.remove(orderId);
      _attachments.remove(orderId);
      _persistDrafts();
      _persistAddedItems();
      _submittedAt[orderId] = DateTime.now();
      // Serverdan qaytgan (narxlangan) buyurtmani lokal ro'yxatlarga qo'llaymiz:
      // asosiy sahifada undo oynasi davomida "Yuborilgan" ko'rinishida qoladi,
      // tarixga esa darhol tushadi.
      if (updated != null) {
        final i = orders.indexWhere((o) => o.id == updated.id);
        if (i >= 0) orders[i] = updated;
        historyOrders.removeWhere((o) => o.id == updated.id);
        historyOrders.insert(0, updated);
      }
      submittingOrderId = null;
      // Undo oynasi tugagach ro'yxatni qayta filtrlaymiz — karta asosiy
      // sahifadan tarixga o'tishi uchun.
      Timer(undoWindow + const Duration(seconds: 1), () {
        if (!_disposed) notifyListeners();
      });
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
      final updated = await _service.revertOrder(orderId);
      _submittedAt.remove(orderId);
      // Qaytarib olingan buyurtma tarixdan chiqib, asosiy ro'yxatga qaytadi.
      historyOrders.removeWhere((o) => o.id == orderId);
      if (updated != null) {
        final i = orders.indexWhere((o) => o.id == updated.id);
        if (i >= 0) {
          orders[i] = updated;
        } else {
          orders.insert(0, updated);
        }
        // Oldin yuborilgan biriktirmalar qayta yuborishda yo'qolmasligi uchun.
        seedAttachments(updated.id, updated.attachments);
      }
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
      historyOrders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return;
    }

    final order = YukOrder.fromJson(event.order);
    final index = orders.indexWhere((o) => o.id == order.id);
    if (_isDone(order)) {
      // Yuborilgan buyurtma — tarixga tushadi. Asosiy ro'yxatda bor bo'lsa
      // yangilaymiz (undo oynasi davomida ko'rinib turadi), yo'q bo'lsa
      // qo'shmaymiz — asosiy sahifa faqat pending uchun.
      if (index >= 0) orders[index] = order;
      historyOrders.removeWhere((o) => o.id == order.id);
      historyOrders.insert(0, order);
    } else {
      // Pending buyurtma — asosiy ro'yxatga (tarixdan chiqarib) qo'llaymiz.
      if (index >= 0) {
        orders[index] = order; // bor bo'lsa almashtir
      } else {
        orders.add(order); // yo'q bo'lsa qo'sh
      }
      historyOrders.removeWhere((o) => o.id == order.id);
    }
    // Socket'dan xabar keldi — demak online'miz.
    isOffline = false;
    // Buyurtma yuborilgan bo'lsa eski lokal qoralamani tozalaymiz.
    _pruneDoneDrafts();
    // Yangilangan ro'yxatni keshlaymiz.
    _persistOrders();
    notifyListeners();

    // Profil ochilgan bo'lsa kunlik hisob daftarini ham yangilaymiz —
    // Rasxod/Itog real time o'zgarishi uchun. Debounce: har draft
    // hodisasida emas, hodisalar tinchigach bir marta.
    if (_ledgerLoadedOnce) {
      _ledgerRefreshTimer?.cancel();
      _ledgerRefreshTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!_disposed) _refreshLedgerSilently();
      });
    }
  }

  // Ledgerni spinner ko'rsatmasdan (jim) yangilash — socket hodisalari uchun.
  Future<void> _refreshLedgerSilently() async {
    try {
      ledger = await _service.fetchLedger();
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Real-time yangilash muvaffaqiyatsiz bo'lsa jim qolamiz — foydalanuvchi
      // pull-to-refresh bilan qayta olishi mumkin.
    }
  }

  // dispose'dan keyin kechikkan timerlar notifyListeners chaqirmasligi uchun.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    disconnectSocket();
    for (final t in _draftTimers.values) {
      t.cancel();
    }
    _draftTimers.clear();
    _ledgerRefreshTimer?.cancel();
    super.dispose();
  }
}
