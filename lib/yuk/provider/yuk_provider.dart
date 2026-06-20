import 'package:flutter/material.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/services/yuk_service.dart';

// Bitta item uchun lokal narx holati.
typedef ItemPrice = ({double price, double subtotal});

// Yuk keltiruvchi bosh ekrani uchun holat boshqaruvchi.
class YukProvider extends ChangeNotifier {
  final YukService _service = YukService();

  List<YukOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

  // Lokal narxlar: orderId -> productId -> {price, subtotal}.
  // Buyurtma yuborilguncha shu yerda turadi.
  final Map<int, Map<int, ItemPrice>> _prices = {};

  // Hozir yuborilayotgan buyurtma id (spinner uchun). null bo'lsa hech nima.
  int? submittingOrderId;

  // Berilgan sklad_id ga tegishli buyurtmalar.
  List<YukOrder> ordersForSklad(int skladId) =>
      orders.where((o) => o.skladId == skladId).toList();

  Future<void> fetchOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      orders = await _service.fetchOrders();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Bitta item narxini saqlash.
  void setItemPrice(int orderId, int productId, double price, double subtotal) {
    final map = _prices.putIfAbsent(orderId, () => {});
    map[productId] = (price: price, subtotal: subtotal);
    notifyListeners();
  }

  // Bitta item narxini olish (yo'q bo'lsa null).
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

    submittingOrderId = orderId;
    errorMessage = null;
    notifyListeners();

    try {
      final items = map.entries
          .map((e) => <String, dynamic>{
                'product_id': e.key,
                'price': e.value.price,
                'subtotal': e.value.subtotal,
              })
          .toList();
      final total = orderTotal(orderId);

      await _service.priceOrder(orderId, items, total);

      // Yuborilgach lokal narxni tozala va ro'yxatni yangila.
      _prices.remove(orderId);
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
}
