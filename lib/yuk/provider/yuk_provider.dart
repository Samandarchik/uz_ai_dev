import 'package:flutter/material.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/services/yuk_service.dart';

// Yuk keltiruvchi bosh ekrani uchun holat boshqaruvchi.
class YukProvider extends ChangeNotifier {
  final YukService _service = YukService();

  List<YukOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

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
}
