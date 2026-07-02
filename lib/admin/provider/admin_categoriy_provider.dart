import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/category_model.dart';
import 'package:uz_ai_dev/admin/services/admin_categoriy.dart';

class CategoryProviderAdmin extends ChangeNotifier {
  final ApiAdminService _service = ApiAdminService();

  List<CategoryProductAdmin> _categories = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<CategoryProductAdmin> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get all categories
  Future<void> getCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _service.getCategories();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reorder categories
  Future<bool> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();

    final ids = _categories.map((c) => c.id).toList();
    final success = await _service.reorderCategories(ids);
    if (!success) {
      // Qaytarish
      await getCategories();
    }
    return success;
  }

}
