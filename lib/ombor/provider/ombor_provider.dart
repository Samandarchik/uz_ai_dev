import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/network/order_socket.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/services/ombor_service.dart';

// Ombor bosh ekrani uchun holat boshqaruvchi.
class OmborProvider extends ChangeNotifier {
  final OmborService _service = OmborService();

  // Mahsulotlar source (manba) bo'yicha guruhlangan:
  // kalitlar — "samarqand", "toshkent", "zagranitsa", "boshqa".
  Map<String, List<OmborProduct>> productsBySource = {};
  bool isLoading = false;
  String? errorMessage;

  // Ko'rsatiladigan source guruhlari QAT'IY tartibda:
  // samarqand, toshkent, zagranitsa, boshqa — faqat mahsuloti borlari.
  // Kutilmagan kalit kelsa ham yo'qolmasligi uchun oxiriga qo'shiladi.
  List<String> get orderedSources {
    final result = <String>[];
    for (final code in omborSourceOrder) {
      final products = productsBySource[code];
      if (products != null && products.isNotEmpty) {
        result.add(code);
      }
    }
    for (final code in productsBySource.keys) {
      if (!result.contains(code) &&
          (productsBySource[code]?.isNotEmpty ?? false)) {
        result.add(code);
      }
    }
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
      productsBySource = await _service.fetchProducts();
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

  // GET /api/orders -> ombor userning o'z buyurtmalari.
  // Eng yangisi yuqorida bo'lishi uchun id bo'yicha kamayuvchi tartiblanadi.
  Future<void> fetchMyOrders() async {
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
      // Milli-birlikdan haqiqiy miqdorga: 1200 -> 1.2 (xatosiz).
      final items = _cart.entries
          .map((e) => {'product_id': e.key, 'count': e.value / 1000.0})
          .toList();
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

  // ─────────────────────── Real-time (WebSocket) ───────────────────────
  StreamSubscription<OrderSocketEvent>? _socketSub;

  // WebSocket'ga ulanib, buyurtma hodisalarini tinglaymiz. fetchMyOrders bilan
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

  @override
  void dispose() {
    disconnectSocket();
    super.dispose();
  }
}
