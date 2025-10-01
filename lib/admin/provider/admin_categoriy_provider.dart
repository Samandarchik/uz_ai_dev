import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/admin_categoriy.dart';

class CategoryProviderAdmin extends ChangeNotifier {
  final ApiAdminService _service = ApiAdminService();

  List<CategoryProductAdmin> _categories = [];
  bool _isLoading = false;
  String? _error;
  CategoryProductAdmin? _selectedCategory;

  // Getters
  List<CategoryProductAdmin> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CategoryProductAdmin? get selectedCategory => _selectedCategory;

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

  // Create new category
  Future<bool> createCategory(CategoryProductAdmin category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newCategory = await _service.createCategory(category);
      _categories.add(newCategory);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update existing category
  Future<bool> updateCategory(CategoryProductAdmin category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedCategory = await _service.updateCategory(category);
      final index = _categories.indexWhere((c) => c.id == updatedCategory.id);
      if (index != -1) {
        _categories[index] = updatedCategory;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete category
  Future<bool> deleteCategory(CategoryProductAdmin category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.deleteCategory(category);
      _categories.removeWhere((c) => c.id == category.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get category by ID
  Future<CategoryProductAdmin?> getCategoryById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final category = await _service.getCategoryById(id);
      _selectedCategory = category;
      _isLoading = false;
      notifyListeners();
      return category;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Set selected category
  void setSelectedCategory(CategoryProductAdmin? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _categories = [];
    _selectedCategory = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
