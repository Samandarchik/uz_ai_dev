import 'package:flutter/material.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/services/ombor_service.dart';

// Ombor bosh ekrani uchun holat boshqaruvchi.
class OmborProvider extends ChangeNotifier {
  final OmborService _service = OmborService();

  Map<String, List<OmborProduct>> productsByCategory = {};
  bool isLoading = false;
  String? errorMessage;

  List<String> get categories => productsByCategory.keys.toList();

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

  // Mahsulotni savatdan butunlay olib tashlash.
  void removeFromCart(int productId) {
    _cart.remove(productId);
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
      productsByCategory = await _service.fetchProducts();
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

  // Hozir qabul qilinayotgan buyurtma id (spinner uchun).
  int? acceptingOrderId;

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

  // Narxlangan buyurtmani qabul qilish: har bir mahsulot uchun rasm/video.
  // images/videos: product_id -> lokal fayl yo'li.
  // Muvaffaqiyatda ro'yxat yangilanadi. Xato bo'lsa Exception otadi.
  Future<void> acceptOrder(
    int orderId,
    Map<int, double> received,
    Map<int, String> images,
    Map<int, String> videos,
  ) async {
    acceptingOrderId = orderId;
    notifyListeners();
    try {
      await _service.acceptOrder(orderId, received, images, videos);
      await fetchMyOrders();
    } finally {
      acceptingOrderId = null;
      notifyListeners();
    }
  }
}
