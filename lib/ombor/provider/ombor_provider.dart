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
  // product_id -> count (count float bo'lishi mumkin).
  final Map<int, double> _cart = {};

  Map<int, double> get cart => Map.unmodifiable(_cart);

  // Savatdagi har xil mahsulotlar soni.
  int get cartItemCount => _cart.length;

  // Savatdagi umumiy miqdor (countlar yig'indisi).
  double get cartTotalQty =>
      _cart.values.fold(0.0, (sum, count) => sum + count);

  bool isSubmitting = false;

  double countOf(int productId) => _cart[productId] ?? 0;

  // Mahsulotni 1 taga oshirish (yo'q bo'lsa qo'shadi).
  void addToCart(int productId, {double step = 1}) {
    _cart[productId] = (_cart[productId] ?? 0) + step;
    notifyListeners();
  }

  // Mahsulotni 1 taga kamaytirish; 0 ga tushsa savatdan olib tashlanadi.
  void decrement(int productId, {double step = 1}) {
    final current = _cart[productId] ?? 0;
    final next = current - step;
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

  // Aniq miqdorni o'rnatish; <=0 bo'lsa olib tashlanadi.
  void setCount(int productId, double count) {
    if (count <= 0) {
      _cart.remove(productId);
    } else {
      _cart[productId] = count;
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
    if (_cart.isEmpty) {
      throw Exception('Savat bo\'sh');
    }

    isSubmitting = true;
    notifyListeners();

    try {
      final items = _cart.entries
          .map((e) => {'product_id': e.key, 'count': e.value})
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
    Map<int, String> images,
    Map<int, String> videos,
  ) async {
    acceptingOrderId = orderId;
    notifyListeners();
    try {
      await _service.acceptOrder(orderId, images, videos);
      await fetchMyOrders();
    } finally {
      acceptingOrderId = null;
      notifyListeners();
    }
  }
}
