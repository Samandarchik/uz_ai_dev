import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/order_socket.dart';
import 'package:uz_ai_dev/yuk/models/yuk_ledger_model.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/models/yuk_transfer_model.dart';
import 'package:uz_ai_dev/yuk/services/yuk_service.dart';

// Bitta item uchun lokal holat: olingan miqdor va jami summa.
// `zero` — foydalanuvchi IKKALA maydonga ham ataylab 0 yozgan degani
// (bo'sh qoldirilganidan farqi shu): bunday yozuv 0/0 bilan YUBORILADI,
// backend uni "olinmagan" deb yopadi.
typedef ItemPrice = ({double taken, double subtotal, bool zero});

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

  // Joriy user ID (SharedPreferences'dagi 'user' JSON'dan, bir marta o'qiladi).
  // Begona (boshqa yuk keltiruvchi boshlagan, priced_by boshqa) qoralamani
  // seed qilmaslik uchun ishlatiladi — aks holda flushDrafts uni qayta yuborib
  // buyurtma egaligini adashtirib yuborishi mumkin.
  int? _myUserId;
  int get myUserId {
    if (_myUserId != null) return _myUserId!;
    try {
      final raw = _storage.getString(key: 'user');
      if (raw.isNotEmpty) {
        final u = jsonDecode(raw);
        if (u is Map && u['id'] is num) {
          _myUserId = (u['id'] as num).toInt();
        }
      }
    } catch (_) {
      // Buzuq JSON — 0 qaytaramiz (hech kimga mos kelmaydi).
    }
    return _myUserId ?? 0;
  }

  // Shu buyurtmaning qoralamasini seed qilish menga joizmi: hali hech kim
  // boshlamagan (priced_by=0) yoki o'zim boshlagan bo'lsa — ha.
  bool canSeedOrder(YukOrder order) =>
      order.pricedBy == 0 || order.pricedBy == myUserId;

  // Shu buyurtmadagi shu mahsulot ombor tomonidan O'CHIRILGANMI (soft-delete).
  // O'chirilgan item hech qachon narxlanmaydi: submit items[]ga ham,
  // draftga ham kirmaydi.
  bool _isDeletedItem(int orderId, int productId) {
    for (final o in orders) {
      if (o.id != orderId) continue;
      for (final i in o.items) {
        if (i.productId == productId) return i.deleted;
      }
      return false;
    }
    return false;
  }

  // Ombor o'chirgan itemlarning lokal narx qoralamalarini tozalash —
  // fetchOrders va socket upsert'dan keyin chaqiriladi, o'chirilgan item
  // SharedPreferences draftida ham qolib ketmasin.
  void _pruneDeletedItemPrices() {
    var changed = false;
    for (final o in orders) {
      final map = _prices[o.id];
      if (map == null) continue;
      for (final item in o.items) {
        if (item.deleted && map.containsKey(item.productId)) {
          map.remove(item.productId);
          changed = true;
        }
      }
      if (map.isEmpty) _prices.remove(o.id);
    }
    if (changed) _persistDrafts();
  }

  // Shu buyurtma uchun hali serverga yuborilmagan (debounce kutayotgan)
  // qoralama bormi — bor bo'lsa socketdan kelgan eski qiymat maydonlarni
  // bosib qo'ymasligi kerak (real-time sinxronlashda ishlatiladi).
  bool draftSaveScheduled(int orderId) => _draftTimers.containsKey(orderId);

  // Hozir yuborilayotgan buyurtma id (spinner uchun). null bo'lsa hech nima.
  int? submittingOrderId;

  // Hozir qaytarib olinayotgan buyurtma id (spinner uchun).
  int? revertingOrderId;

  // Jamlangan kunlik ro'yxatning bitta "Yuborish"/"Qaytarib olish" tugmasi
  // uchun: hozir qaysi skladning buyurtmalari yuborilyapti/qaytarilyapti.
  int? submittingSkladId;
  int? revertingSkladId;

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

  // Sklad bo'yicha eng katta qolgan undo vaqti — jamlangan kartaning bitta
  // "Qaytarib olish" tugmasi sanog'i uchun.
  Duration undoRemainingForSklad(int skladId) {
    var max = Duration.zero;
    for (final o in orders) {
      if (o.skladId != skladId || !_isDone(o)) continue;
      final left = undoRemaining(o.id);
      if (left > max) max = left;
    }
    return max;
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

  // Tarix ekrani (kunlik kartalar): faqat O'ZIM narxlagan yuborilgan
  // buyurtmalar — priced_by mening ID'im yoki 0 (egasi yozilmagan eski
  // yozuvlar). Barcha skladlar birga, yangisi tepada; kunlik guruhlash
  // UI'da (groupYukOrdersByDay) qilinadi.
  List<YukOrder> get myHistoryOrders {
    final list = historyOrders
        .where((o) =>
            _isDone(o) && (o.pricedBy == 0 || o.pricedBy == myUserId))
        .toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a.created) ?? DateTime(2000);
      final db = DateTime.tryParse(b.created) ?? DateTime(2000);
      return db.compareTo(da);
    });
    return list;
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
      // Ombor o'chirgan itemlarning qoralamalari ham tozalanadi.
      _pruneDeletedItemPrices();
      // Ro'yxatda umuman yo'q buyurtmalarning qoralamalari ham o'chadi —
      // eskirib qolgan lokal qoralama flushDrafts bilan qayta serverga
      // ketib yurmasin (masalan source filtri bilan yashiringan yoki
      // allaqachon yopilgan buyurtmalar).
      _pruneMissingDrafts();
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

  // Bitta kunning xarajat tafsiloti (profil jadvalidagi kun bosilganda
  // ochiladigan bottom sheet uchun). Holat saqlanmaydi — sheet o'zi kutadi.
  Future<LedgerDayDetail> fetchLedgerDay(String date) =>
      _service.fetchLedgerDay(date);

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
  // `zero: true` — foydalanuvchi ikkala maydonga ham ataylab 0 yozgan
  // (UI controller matnidan aniqlanadi); bunday yozuv 0/0 bilan yuboriladi.
  void setItemPrice(
    int orderId,
    int productId,
    double taken,
    double subtotal, {
    bool zero = false,
  }) {
    // O'chirilgan itemga narx yozilmaydi (UI'da maydon ham yo'q — himoya).
    if (_isDeletedItem(orderId, productId)) return;
    final map = _prices.putIfAbsent(orderId, () => {});
    map[productId] = (taken: taken, subtotal: subtotal, zero: zero);
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
          'zero': v.zero,
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
          // Eski (zero'siz saqlangan) qoralamalar ham o'qilishi uchun
          // kalit bo'lmasa false olinadi.
          final zero = v['zero'] == true;
          map[pid] = (taken: taken, subtotal: subtotal, zero: zero);
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

  // Serverdan kelgan (pending) ro'yxatda YO'Q buyurtmalarning lokal
  // qoralamalarini tozalash. Faqat fetchOrders muvaffaqiyatli bo'lganda
  // chaqiriladi (offline'da kesh saqlanadi).
  void _pruneMissingDrafts() {
    final ids = orders.map((o) => o.id).toSet();
    var changed = false;
    var addedChanged = false;
    for (final id in _prices.keys.toList()) {
      if (!ids.contains(id)) {
        _prices.remove(id);
        _draftTimers.remove(id)?.cancel();
        changed = true;
      }
    }
    for (final id in _addedItems.keys.toList()) {
      if (!ids.contains(id)) {
        _addedItems.remove(id);
        addedChanged = true;
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
      // O'chirilgan itemlar draftga ham kirmaydi.
      final items = map.entries
          .where((e) => !_isDeletedItem(orderId, e.key))
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
    // O'chirilgan item seed qilinmaydi — draftga qayta kirib qolmasin.
    if (_isDeletedItem(orderId, productId)) return;
    final map = _prices.putIfAbsent(orderId, () => {});
    // Seed (server/socket qiymati) hech qachon "ataylab 0" emas.
    map[productId] = (taken: taken, subtotal: subtotal, zero: false);
  }

  // Bitta item holatini olish (yo'q bo'lsa null).
  ItemPrice? getItemPrice(int orderId, int productId) {
    return _prices[orderId]?[productId];
  }

  // Yozuv yuborishga tayyormi: yuk faqat SUMMA (subtotal) kiritadi — soni
  // maydoni qulf (omborchi buyurtma qilgan son = taken). Summa > 0 bo'lsa
  // yuboriladi; YOKI foydalanuvchi summaga ataylab 0 yozgan (zero — backend
  // "olinmagan" deb yopadi). Bo'sh summa pending'da qoladi.
  static bool _isFilled(ItemPrice p) => p.subtotal > 0 || p.zero;

  // UI uchun: shu qator yuborishga tayyormi (to'liq to'ldirilgan yoki
  // ataylab 0/0 yozilgan). Yozuv umuman bo'lmasa yoki item o'chirilgan
  // bo'lsa — tayyor emas.
  bool isRowSubmittable(int orderId, int productId) {
    if (_isDeletedItem(orderId, productId)) return false;
    final p = _prices[orderId]?[productId];
    return p != null && _isFilled(p);
  }

  // Buyurtmaning to'liq to'ldirilgan (yuborishga tayyor) yozuvlari.
  // Ombor o'chirgan itemlar HECH QACHON kirmaydi.
  Map<int, ItemPrice> _filledPrices(int orderId) {
    final map = _prices[orderId];
    if (map == null || map.isEmpty) return const {};
    return {
      for (final e in map.entries)
        if (_isFilled(e.value) && !_isDeletedItem(orderId, e.key))
          e.key: e.value,
    };
  }

  // Buyurtmada yuboriladigan narsa bormi: kamida bitta to'liq to'ldirilgan
  // yozuv YOKI qo'shilgan proche/rasxod.
  bool _hasSubmittable(int orderId) {
    if (_filledPrices(orderId).isNotEmpty) return true;
    final added = _addedItems[orderId];
    return added != null && added.isNotEmpty;
  }

  // Katalogdagi (buyurtmadagi) itemlar uchun kiritilgan subtotal yig'indisi.
  // O'chirilgan itemlarning (eski) qoralamasi hisobga KIRMAYDI.
  double _catalogTotal(int orderId) {
    final map = _prices[orderId];
    if (map == null) return 0;
    var sum = 0.0;
    for (final e in map.entries) {
      if (_isDeletedItem(orderId, e.key)) continue;
      sum += e.value.subtotal;
    }
    return sum;
  }

  // Buyurtma uchun MAHSULOT jami summasi: katalog narxlari + qo'shilgan
  // proche mahsulotlar. Rasxod (xarajat) bunga KIRMAYDI —
  // u addedExpensesTotal'da alohida.
  double orderTotal(int orderId) {
    return _catalogTotal(orderId) + addedProductsTotal(orderId);
  }

  // Yuborish tugmasi uchun: kamida bitta TO'LIQ to'ldirilgan yozuv (soni ham,
  // summa ham) yoki qo'shimcha yozuv bormi. Chala yozuvning o'zi (faqat soni
  // yozilgan) yuborishni yoqmaydi.
  bool hasAnyPrice(int orderId) => _hasSubmittable(orderId);

  // Skladning yuborilmagan buyurtmalaridan birortasida to'liq to'ldirilgan
  // yozuv yoki qo'shimcha yozuv bormi (jamlangan "Yuborish" tugmasi uchun).
  bool hasAnyPriceForSklad(int skladId) => orders.any(
      (o) => o.skladId == skladId && !_isDone(o) && hasAnyPrice(o.id));

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
        if ((it.isProche || it.isRasxod) && !it.deleted)
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

  // Bitta buyurtmani backendga yuborish (narxlash) — yadro. FAQAT to'liq
  // to'ldirilgan (taken>0 va subtotal>0, yoki ataylab 0/0 yozilgan — zero)
  // itemlar yuboriladi; backend ularni
  // yangi `narxlandi` buyurtmaga ajratadi, chala/bo'sh itemlar esa ASL
  // buyurtmada (o'sha id bilan) pending bo'lib qoladi — lokal qoralamalari
  // saqlanadi. Xato bo'lsa Exception otadi.
  Future<void> _submitOne(int orderId) async {
    final filled = _filledPrices(orderId);
    final added = _addedItems[orderId] ?? const <YukAddedItem>[];

    // Yuboriladigan hech narsa bo'lmasa API chaqirmaymiz (chaqiruvchi
    // filtrlashi kerak, bu — himoya).
    if (filled.isEmpty && added.isEmpty) return;

    // Kutib turgan qoralama saqlash bo'lsa bekor qilamiz — endi yakuniy narx
    // yuborilmoqda. (Qolgan chala yozuvlar keyingi o'zgarishda yoki
    // flushDrafts'da qayta saqlanadi.)
    _draftTimers.remove(orderId)?.cancel();

    final items = filled.entries
        .map((e) => <String, dynamic>{
              'product_id': e.key,
              'taken': e.value.taken,
              'subtotal': e.value.subtotal,
            })
        .toList();
    // Yuboriladigan mahsulot jami: FAQAT to'liq to'ldirilgan itemlar + proche.
    // (orderTotal() UI'dagi jonli hisob uchun o'zgarishsiz qoladi.)
    var total = addedProductsTotal(orderId);
    for (final v in filled.values) {
      total += v.subtotal;
    }

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

    // Yuborilgach FAQAT yuborilgan (to'liq to'ldirilgan) yozuvlarni tozalaymiz
    // — chala qoralamalar asl (pending qolgan) buyurtmada ko'rinib,
    // tahrirlanadigan bo'lib qoladi. Qo'shilganlar va biriktirmalar yuborildi
    // — ular tozalanadi.
    final remaining = _prices[orderId];
    if (remaining != null) {
      for (final pid in filled.keys) {
        remaining.remove(pid);
      }
      if (remaining.isEmpty) _prices.remove(orderId);
    }
    _addedItems.remove(orderId);
    _attachments.remove(orderId);
    _persistDrafts();
    _persistAddedItems();
    // Backend buyurtmani ajratsa javob YANGI id bilan keladi — "qaytarib
    // olish" oynasi o'sha (yuborilgan) buyurtma id'siga bog'lanadi.
    _submittedAt[updated?.id ?? orderId] = DateTime.now();
    // Serverdan qaytgan (narxlangan) buyurtmani lokal ro'yxatlarga qo'llaymiz:
    // asosiy sahifada undo oynasi davomida "Yuborilgan" ko'rinishida qoladi,
    // tarixga esa darhol tushadi. Split'da bu butunlay yangi buyurtma —
    // ro'yxatda yo'q bo'lsa qo'shamiz (undo tugmasi ko'rinishi uchun).
    if (updated != null) {
      final i = orders.indexWhere((o) => o.id == updated.id);
      if (i >= 0) {
        orders[i] = updated;
      } else {
        orders.add(updated);
      }
      historyOrders.removeWhere((o) => o.id == updated.id);
      historyOrders.insert(0, updated);
    }
  }

  // Narxlangan buyurtmani backendga yuborish (omborga qaytarish).
  // Faqat to'liq to'ldirilgan itemlar ketadi; chalalari pending'da qoladi.
  Future<bool> submitPrices(int orderId) async {
    if (!_hasSubmittable(orderId)) {
      errorMessage = 'Yuboriladigan narx kiritilmagan';
      notifyListeners();
      return false;
    }

    submittingOrderId = orderId;
    errorMessage = null;
    notifyListeners();

    try {
      await _submitOne(orderId);
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

  // Skladning yuborsa bo'ladigan (kamida bitta to'liq to'ldirilgan yozuvi
  // yoki qo'shilgan itemi bor) buyurtmalarini birdan yuborish — kunlik
  // achotni yopish. Buyurtmalar sana tartibida ketadi; to'liq to'ldirilmagan
  // itemlar YUBORILMAYDI — ular asl buyurtmada pending bo'lib qoladi
  // (hech narsasi yo'q buyurtma jimgina o'tkazib yuboriladi).
  // O'rtada xato chiqsa to'xtaydi (yuborilganlari yuborilgan bo'lib qoladi,
  // qolganini qayta "Yuborish" bilan davom ettirsa bo'ladi).
  Future<bool> submitAllForSklad(int skladId) async {
    final targets = orders
        .where((o) =>
            o.skladId == skladId && !_isDone(o) && _hasSubmittable(o.id))
        .toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.created) ?? DateTime(2000);
        final db = DateTime.tryParse(b.created) ?? DateTime(2000);
        return da.compareTo(db);
      });
    if (targets.isEmpty) {
      errorMessage = 'Yuboriladigan narx kiritilmagan';
      notifyListeners();
      return false;
    }

    submittingSkladId = skladId;
    errorMessage = null;
    notifyListeners();

    var okAll = true;
    for (final o in targets) {
      try {
        await _submitOne(o.id);
        notifyListeners();
      } catch (e) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        okAll = false;
        break;
      }
    }

    submittingSkladId = null;
    Timer(undoWindow + const Duration(seconds: 1), () {
      if (!_disposed) notifyListeners();
    });
    await fetchOrders();
    return okAll;
  }

  // Endigina yopilgan achotni butunlay qaytarib olish: skladning undo oynasi
  // hali ochiq bo'lgan hamma yuborilgan buyurtmalari qaytariladi.
  Future<bool> revertAllForSklad(int skladId) async {
    final targets = orders
        .where((o) =>
            o.skladId == skladId &&
            _isDone(o) &&
            undoRemaining(o.id) > Duration.zero)
        .toList();
    if (targets.isEmpty) return false;

    revertingSkladId = skladId;
    errorMessage = null;
    notifyListeners();

    var okAll = true;
    for (final o in targets) {
      try {
        final updated = await _service.revertOrder(o.id);
        _submittedAt.remove(o.id);
        historyOrders.removeWhere((x) => x.id == o.id);
        if (updated != null) {
          final i = orders.indexWhere((x) => x.id == updated.id);
          if (i >= 0) {
            orders[i] = updated;
          } else {
            orders.insert(0, updated);
          }
          seedAttachments(updated.id, updated.attachments);
        }
      } catch (e) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        okAll = false;
      }
    }

    revertingSkladId = null;
    await fetchOrders();
    return okAll;
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
  StreamSubscription<TransferSocketEvent>? _transferSocketSub;

  // WebSocket'ga ulanib, buyurtma hodisalarini tinglaymiz. fetchOrders bilan
  // birga ishlaydi (u boshlang'ich sync, bu — real-time yangilanish).
  void connectSocket() {
    _socketSub ??= OrderSocket.instance.events.listen(_onSocketEvent);
    _transferSocketSub ??=
        OrderSocket.instance.transferEvents.listen(_onTransferSocketEvent);
    OrderSocket.instance.connect();
  }

  // Ekrandan chiqqanda yoki logout'da ulanishni uzamiz.
  void disconnectSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _transferSocketSub?.cancel();
    _transferSocketSub = null;
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
    // Ombor itemni o'chirgan bo'lsa ('item_deleted' upsert) uning lokal
    // narx qoralamasi ham o'chadi — draft/submit'ga qayta kirmasin.
    _pruneDeletedItemPrices();
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

  // ────────────── Targovli'dan kelgan pullar (qabul qilish) ──────────────

  // Bosh ekranda ko'rsatiladigan KUTILAYOTGAN pullar (status=pending).
  List<YukTransfer> transfers = [];
  // Hozir qaror qilinayotgan pul id (tugma spinner'i uchun).
  int? decidingTransferId;

  // Kutilayotgan pullarni serverdan olish (bosh ekran ochilganda va
  // pull-to-refresh'da chaqiriladi). Xato bo'lsa jim qolamiz — pul bloki
  // asosiy buyurtmalar oqimini to'sib qo'ymasin.
  Future<void> fetchTransfers() async {
    try {
      transfers = await _service.fetchTransfers(status: 'pending');
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  // Pulni qabul qilish yoki rad etish. Muvaffaqiyatda ro'yxatdan chiqadi;
  // qabul bo'lsa ledger prixodi ham yangilanadi. Xatoda Exception otiladi
  // (UI snackbar ko'rsatadi).
  Future<void> decideTransfer(
    int id, {
    required bool accept,
    String reason = '',
  }) async {
    decidingTransferId = id;
    notifyListeners();
    try {
      await _service.decideTransfer(id, accept: accept, reason: reason);
      transfers.removeWhere((t) => t.id == id);
      if (accept && _ledgerLoadedOnce) {
        _refreshLedgerSilently();
      }
    } finally {
      decidingTransferId = null;
      if (!_disposed) notifyListeners();
    }
  }

  // Real-time: pul keldi/o'zgardi/o'chirildi — pending ro'yxatini yangilaymiz.
  void _onTransferSocketEvent(TransferSocketEvent event) {
    final t = YukTransfer.fromJson(event.transfer);
    if (t.id == 0) return;
    transfers.removeWhere((x) => x.id == t.id);
    if (event.action != 'deleted' && t.isPending) {
      transfers.insert(0, t);
    }
    if (!_disposed) notifyListeners();
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
