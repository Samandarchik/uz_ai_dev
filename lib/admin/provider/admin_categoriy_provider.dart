// admin/provider/admin_categoriy_provider.dart — kategoriyalar holati
// (CategoryProviderAdmin, ChangeNotifier): categories ro'yxatini
// ApiAdminService orqali oladi (getCategories) va tartibini o'zgartiradi
// (reorderCategories); isLoading/error holatini ushlaydi.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/category_model.dart';
import 'package:uz_ai_dev/admin/services/admin_categoriy.dart';
import 'package:uz_ai_dev/core/clearable_provider.dart';

class CategoryProviderAdmin extends ChangeNotifier with ClearableProvider {
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
  // Eslatma: onReorderItem callback'i newIndex'ni allaqachon to'g'irlab beradi,
  // shuning uchun bu yerda qo'lda kompensatsiya kerak emas.
  Future<bool> reorderCategories(int oldIndex, int newIndex) async {
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

  // Logout: kategoriyalar va yuklanish/xato holatini tozalaymiz.
  @override
  void clear() {
    _categories = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
