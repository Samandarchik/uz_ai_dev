import 'package:flutter/material.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/services/ombor_service.dart';

// Ombor bosh ekrani uchun holat boshqaruvchi.
class OmborProvider extends ChangeNotifier {
  final OmborService _service = OmborService();

  Map<String, List<OmborProduct>> productsByCategory = {};
  bool isLoading = false;
  String? errorMessage;

  List<String> get categories => productsByCategory.keys.toList();

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
}
