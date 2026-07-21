// ombor/provider/ombor_provider.dart — Ombor (bozor) roli markaziy provideri: OmborProvider
// (ChangeNotifier). Holat: productsByCategory, allCategories, savat (_cart — milli-birlik butun
// son), myOrders; submitOrder/acceptOrderItem/deleteOrderItem va WebSocket real-time yangilanish.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/clearable_provider.dart';
import 'package:uz_ai_dev/core/network/order_socket.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/services/ombor_service.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';

// Ombor bosh ekrani uchun holat boshqaruvchi.
class OmborProvider extends ChangeNotifier with ClearableProvider {
  final OmborService _service = OmborService();

  Map<String, List<OmborProduct>> productsByCategory = {};
  // GET /api/categories dan kelgan ro'yxat (rasm + server tartibi).
  List<OmborCategory> allCategories = [];
  bool isLoading = false;
  String? errorMessage;

  List<String> get categories => productsByCategory.keys.toList();

  // ─────────────────────── Ombor skladlari ───────────────────────
  // SharedPreferences'dagi 'user' JSON dan bir marta o'qiladi. Kartochkadagi
  // «Qoldiq» qatori va «Kam qolganlar» sahifasi shu skladlar bo'yicha ishlaydi.
  List<int> skladIds = [];
  bool _skladsLoaded = false;

  // Birinchi (asosiy) sklad — kartochkada qoldiq shu sklad bo'yicha ko'rinadi.
  int? get primarySkladId => skladIds.isEmpty ? null : skladIds.first;

  Future<void> ensureSklads() async {
    if (_skladsLoaded) return;
    _skladsLoaded = true;
    skladIds = await loadUserSklads();
    notifyListeners();
  }

  // Admin paneldagi kabi ko'rsatiladigan kategoriyalar: server tartibida,
  // faqat bozor mahsuloti borlari. /api/categories da topilmagan guruh
  // nomlari ham yo'qolmasligi uchun oxiriga (rasmsiz) qo'shiladi.
  List<OmborCategory> get orderedCategories {
    final result = <OmborCategory>[];
    final seen = <String>{};
    for (final c in allCategories) {
      if (productsByCategory.containsKey(c.name)) {
        result.add(c);
        seen.add(c.name);
      }
    }
    for (final name in productsByCategory.keys) {
      if (!seen.contains(name)) {
        result.add(OmborCategory(id: 0, name: name));
      }
    }
    return result;
  }

  // Kategoriya ichidagi mahsulotlar soni (ro'yxat subtitle uchun).
  int productCount(String categoryName) =>
      productsByCategory[categoryName]?.length ?? 0;

  // Mahsulotni id bo'yicha topish (savat submit'da type kerak).
  OmborProduct? findProductById(int productId) {
    for (final products in productsByCategory.values) {
      for (final p in products) {
        if (p.id == productId) return p;
      }
    }
    return null;
  }

  // Qidiruv uchun barcha mahsulotlar (kategoriya nomi bilan birga).
  List<MapEntry<String, OmborProduct>> get allProductsWithCategory {
    final result = <MapEntry<String, OmborProduct>>[];
    productsByCategory.forEach((category, products) {
      for (final p in products) {
        result.add(MapEntry(category, p));
      }
    });
    return result;
  }

  // ─────────────────────── Savatcha holati ───────────────────────
  // product_id -> miqdor * 1000 ("milli-birlik", BUTUN son). Float emas:
  // 0.4 -> 400; 400+400+400 = 1200 -> 1.2 (float xatosi yo'q). Ko'rsatishda
  // va yuborishda /1000 qilinadi.
  final Map<int, int> _cart = {};

  Map<int, int> get cart => Map.unmodifiable(_cart);

  // Savatdagi har xil mahsulotlar soni.
  int get cartItemCount => _cart.length;

  // Savatdagi umumiy miqdor (milli-birlik yig'indisi; ko'rsatishda /1000).
  int get cartTotalMilli => _cart.values.fold(0, (sum, c) => sum + c);

  bool isSubmitting = false;

  // Mahsulot miqdori milli-birlikda (0 = savatda yo'q).
  int countMilli(int productId) => _cart[productId] ?? 0;

  // Bir qadam (stepMilli = bozor gramm * 1000) qo'shish.
  void addToCart(int productId, int stepMilli) {
    _cart[productId] = (_cart[productId] ?? 0) + stepMilli;
    notifyListeners();
  }

  // Bir qadam kamaytirish; 0 ga tushsa savatdan olib tashlanadi.
  void decrement(int productId, int stepMilli) {
    final next = (_cart[productId] ?? 0) - stepMilli;
    if (next <= 0) {
      _cart.remove(productId);
    } else {
      _cart[productId] = next;
    }
    notifyListeners();
  }

  // Miqdorni to'g'ridan-to'g'ri o'rnatish (qo'lda kiritilganda).
  // 0 yoki manfiy bo'lsa savatdan olib tashlanadi.
  void setCountMilli(int productId, int milli) {
    if (milli <= 0) {
      _cart.remove(productId);
    } else {
      _cart[productId] = milli;
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<void> fetchProducts() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Mahsulotlar va kategoriyalar parallel yuklanadi. Kategoriyalar
      // faqat rasm/tartib uchun — xatosi asosiy ro'yxatni to'xtatmaydi.
      final productsFuture = _service.fetchProducts();
      try {
        allCategories = await _service.fetchCategories();
      } catch (_) {
        allCategories = [];
      }
      productsByCategory = await productsFuture;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────── Mening buyurtmalarim ───────────────────────
  List<OmborOrder> myOrders = [];
  bool isLoadingOrders = false;
  String? ordersError;

  // Hozir qabul qilinayotgan item (order id + product id) — qator tugmasida
  // spinner ko'rsatish uchun.
  int? acceptingItemOrderId;
  int? acceptingItemProductId;

  // Hozir o'chirilayotgan item (order id + product id) — qatordagi o'chirish
  // ikonkasida spinner ko'rsatish uchun.
  int? deletingItemOrderId;
  int? deletingItemProductId;

  // GET /api/orders -> ombor userning o'z buyurtmalari.
  // Eng yangisi yuqorida bo'lishi uchun id bo'yicha kamayuvchi tartiblanadi.
  //
  // Bir vaqtda ikkita so'rov ketmasligi uchun yengil guard: bosh ekran ham,
  // «Buyurtmalarim» tabи ham ochilishida chaqiradi — parallel javoblar bir
  // birini eskisi bilan almashtirib qo'ymasin.
  Future<void> fetchMyOrders() async {
    if (isLoadingOrders) return;
    isLoadingOrders = true;
    ordersError = null;
    notifyListeners();

    try {
      final orders = await _service.fetchMyOrders();
      orders.sort((a, b) => b.id.compareTo(a.id));
      myOrders = orders;
    } catch (e) {
      ordersError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
    }
  }

  // Shu mahsulotga BUYURTMA BERILGAN, lekin HALI KELMAGAN miqdor.
  // Kartochkadagi «Buyurtma: X кг» yozuvi uchun — ombor «Kam qolganlar»
  // sahifasidan bir narsani ikki marta buyurtma qilib yubormasligi kerak.
  //
  // Faqat quyidagi itemlar qo'shiladi:
  //  - !accepted — qabul qilingan item allaqachon sklad qoldig'iga kirim
  //    qilingan (backend: stockKirimOnAccept), ya'ni «Qoldiq» ichida
  //    sanalgan. Uni bu yerda ham sanasak — ikki marta hisoblangan bo'lardi.
  //    Aynan item'ning O'Z accepted bayrog'i (order statusi emas) ikki sonni
  //    bir-biridan ajratib turadi: qisman qabul qilingan buyurtmada kelgan
  //    itemlar «Qoldiq»da, kelmaganlari esa shu yerda.
  //  - !deleted — o'chirilgan item umuman kelmaydi.
  //  - itemType == '' — faqat katalog mahsuloti ('rasxod'/'proche' emas).
  //
  // Qiymat gramm kontraktida (кг/л -> butun гр/мл) — ko'rsatishda formatQty.
  double orderedQty(int productId) {
    var sum = 0.0;
    for (final order in myOrders) {
      for (final item in order.items) {
        if (item.productId != productId) continue;
        if (item.accepted || item.deleted) continue;
        if (item.itemType.isNotEmpty) continue;
        sum += item.count;
      }
    }
    return sum;
  }

  // Savatdagi mahsulotlardan buyurtma yuborish.
  // Muvaffaqiyatda savatni tozalaydi va backend message'ini qaytaradi.
  // Xato bo'lsa Exception otadi (UI uni ushlab SnackBar ko'rsatadi).
  Future<String> submitOrder() async {
    // Qayta yuborishni bloklash: tugma tez ikki marta bosilsa ham (UI guard
    // build vaqtida ishlaydi) ikkita bir xil buyurtma yaratilmasin.
    if (isSubmitting) return '';
    if (_cart.isEmpty) {
      throw Exception('Savat bo\'sh');
    }

    isSubmitting = true;
    notifyListeners();

    try {
      // API kontrakt: кг/л mahsulotda count — BUTUN gramm/ml. Savat milli
      // birlikda saqlanadi (kg×1000 == gramm), shuning uchun qiymat
      // o'zgarishsiz yuboriladi. Boshqa birliklar: /1000 (eski semantika).
      final items = _cart.entries.map((e) {
        final type = findProductById(e.key)?.type;
        final num count;
        if (qtyUnitFactor(type) == 1000) {
          count = e.value; // milli == gramm/ml, butun son
        } else {
          final v = e.value / 1000.0;
          count = v % 1 == 0 ? v.toInt() : v;
        }
        return {'product_id': e.key, 'count': count};
      }).toList();
      final message = await _service.submitOrder(items);
      _cart.clear();
      return message;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  // Bitta mahsulotni qabul qilish: kelgan soni + rasm/video (kamida bittasi).
  // Muvaffaqiyatda backend qaytargan TO'LIQ yangilangan order myOrders'da
  // id bo'yicha almashtiriladi (qayta GET shart emas). Xato bo'lsa
  // Exception otadi (UI uni ushlab SnackBar ko'rsatadi).
  Future<void> acceptOrderItem(
    int orderId,
    int productId,
    double received,
    String? imagePath,
    String? videoPath,
  ) async {
    acceptingItemOrderId = orderId;
    acceptingItemProductId = productId;
    notifyListeners();
    try {
      final updated = await _service.acceptOrderItem(
        orderId,
        productId,
        received,
        imagePath,
        videoPath,
      );
      final index = myOrders.indexWhere((o) => o.id == updated.id);
      if (index >= 0) {
        myOrders[index] = updated;
      }
    } finally {
      acceptingItemOrderId = null;
      acceptingItemProductId = null;
      notifyListeners();
    }
  }

  // Bitta mahsulotni buyurtmadan o'chirish (soft-delete). Muvaffaqiyatda
  // backend qaytargan TO'LIQ yangilangan order myOrders'da id bo'yicha
  // almashtiriladi (qayta GET shart emas). Xato bo'lsa Exception otadi
  // (UI uni ushlab SnackBar ko'rsatadi).
  Future<void> deleteOrderItem(int orderId, int productId) async {
    deletingItemOrderId = orderId;
    deletingItemProductId = productId;
    notifyListeners();
    try {
      final updated = await _service.deleteOrderItem(orderId, productId);
      final index = myOrders.indexWhere((o) => o.id == updated.id);
      if (index >= 0) {
        myOrders[index] = updated;
      }
    } finally {
      deletingItemOrderId = null;
      deletingItemProductId = null;
      notifyListeners();
    }
  }

  // ─────────────────────── Real-time (WebSocket) ───────────────────────
  StreamSubscription<OrderSocketEvent>? _socketSub;

  // WebSocket'ga ulanib, buyurtma hodisalarini tinglaymiz. fetchMyOrders bilan
  // birga ishlaydi (u boshlang'ich sync, bu — real-time yangilanish).
  void connectSocket() {
    // connect/disconnect juftligi _socketSub orqali balanslanadi —
    // OrderSocket ref-count to'g'ri ishlashi uchun (qarang: order_socket.dart).
    if (_socketSub != null) return;
    _socketSub = OrderSocket.instance.events.listen(_onSocketEvent);
    OrderSocket.instance.connect();
  }

  // Ekrandan chiqqanda yoki logout'da ulanishni uzamiz.
  void disconnectSocket() {
    if (_socketSub == null) return;
    _socketSub!.cancel();
    _socketSub = null;
    OrderSocket.instance.disconnect();
  }

  // Kelgan hodisani myOrders'ga qo'llash: deleted -> o'chir, aks holda upsert.
  void _onSocketEvent(OrderSocketEvent event) {
    final id = event.order['id'];
    final orderId = (id is int) ? id : int.tryParse(id?.toString() ?? '');
    if (orderId == null) return;

    if (event.action == 'deleted') {
      myOrders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return;
    }

    final order = OmborOrder.fromJson(event.order);
    final index = myOrders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      myOrders[index] = order; // bor bo'lsa almashtir
    } else {
      myOrders.add(order); // yo'q bo'lsa qo'sh
    }
    // Eng yangisi yuqorida bo'lishi uchun id bo'yicha kamayuvchi tartiblash.
    myOrders.sort((a, b) => b.id.compareTo(a.id));
    notifyListeners();
  }

  // Logout: socketni uzib, katalog/savat/buyurtma va holat maydonlarini
  // boshlang'ich holatga qaytaramiz.
  @override
  void clear() {
    disconnectSocket();
    productsByCategory = {};
    allCategories = [];
    isLoading = false;
    errorMessage = null;
    skladIds = [];
    _skladsLoaded = false;
    _cart.clear();
    isSubmitting = false;
    myOrders = [];
    isLoadingOrders = false;
    ordersError = null;
    acceptingItemOrderId = null;
    acceptingItemProductId = null;
    deletingItemOrderId = null;
    deletingItemProductId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectSocket();
    super.dispose();
  }
}
