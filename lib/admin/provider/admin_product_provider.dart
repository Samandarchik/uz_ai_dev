import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/api_product_service.dart';

class ProductProviderAdmin extends ChangeNotifier {
  final ApiProductService _service = ApiProductService();

  List<ProductModelAdmin> _products = [];

  // Har bir kategoriya uchun mahsulotlarni saqlash
  Map<int, List<ProductModelAdmin>> _productsByCategory = {};

  // Qaysi kategoriyalar yuklangani kuzatish
  Set<int> _loadedCategories = {};

  List<ProductModelAdmin> _filteredProducts = [];
  bool _isLoading = false;
  String? _error;
  ProductModelAdmin? _selectedProduct;
  int? _selectedCategoryId;

  // Getters
  List<ProductModelAdmin> get products => _products;
  List<ProductModelAdmin> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ProductModelAdmin? get selectedProduct => _selectedProduct;
  int? get selectedCategoryId => _selectedCategoryId;

  // Get all products
  Future<void> getAllProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _service.getAllProducts();
      _filteredProducts = _products;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get products by category ID (optimized with caching)
  Future<void> getProductsByCategoryId(int categoryId,
      {bool forceRefresh = false}) async {
    // Agar bu kategoriya allaqachon yuklangan bo'lsa va force refresh yo'q bo'lsa
    if (_loadedCategories.contains(categoryId) && !forceRefresh) {
      _filteredProducts = _productsByCategory[categoryId] ?? [];
      _selectedCategoryId = categoryId;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _selectedCategoryId = categoryId;
    notifyListeners();

    try {
      final products = await _service.getProductsByCategoryId(categoryId);

      // Kategoriya mahsulotlarini saqlash
      _productsByCategory[categoryId] = products;
      _loadedCategories.add(categoryId);

      _filteredProducts = products;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter products locally by category
  void filterByCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    if (categoryId == null) {
      _filteredProducts = _products;
    } else {
      _filteredProducts = _products
          .where((product) => product.categoryId == categoryId)
          .toList();
    }
    notifyListeners();
  }

  // Create new product
  Future<bool> createProduct(ProductModelAdmin product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newProduct = await _service.createProduct(product);
      _products.add(newProduct);

      // Tegishli kategoriya keshini yangilash
      if (_productsByCategory.containsKey(newProduct.categoryId)) {
        _productsByCategory[newProduct.categoryId]!.add(newProduct);
      }

      // Agar filter qo'llangan bo'lsa, yangi mahsulotni ham filter qilish
      if (_selectedCategoryId == null ||
          newProduct.categoryId == _selectedCategoryId) {
        _filteredProducts.add(newProduct);
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

  // Update existing product
  Future<bool> updateProduct(ProductModelAdmin product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedProduct = await _service.updateProduct(product);

      // Update in main list
      final index = _products.indexWhere((p) => p.id == updatedProduct.id);
      if (index != -1) {
        _products[index] = updatedProduct;
      }

      // Update in category cache
      if (_productsByCategory.containsKey(updatedProduct.categoryId)) {
        final categoryIndex = _productsByCategory[updatedProduct.categoryId]!
            .indexWhere((p) => p.id == updatedProduct.id);
        if (categoryIndex != -1) {
          _productsByCategory[updatedProduct.categoryId]![categoryIndex] =
              updatedProduct;
        }
      }

      // Update in filtered list
      final filteredIndex =
          _filteredProducts.indexWhere((p) => p.id == updatedProduct.id);
      if (filteredIndex != -1) {
        _filteredProducts[filteredIndex] = updatedProduct;
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

  // Delete product
  Future<bool> deleteProduct(ProductModelAdmin product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.deleteProduct(product);

      _products.removeWhere((p) => p.id == product.id);
      _filteredProducts.removeWhere((p) => p.id == product.id);

      // Kategoriya keshidan o'chirish
      if (_productsByCategory.containsKey(product.categoryId)) {
        _productsByCategory[product.categoryId]!
            .removeWhere((p) => p.id == product.id);
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

  // Get product by ID
  Future<ProductModelAdmin?> getProductById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final product = await _service.getProductById(id);
      _selectedProduct = product;
      _isLoading = false;
      notifyListeners();
      return product;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Set selected product
  void setSelectedProduct(ProductModelAdmin? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  // Clear filter
  void clearFilter() {
    _selectedCategoryId = null;
    _filteredProducts = _products;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Kategoriya keshini tozalash (yangilash kerak bo'lganda)
  void clearCategoryCache(int? categoryId) {
    if (categoryId != null) {
      _productsByCategory.remove(categoryId);
      _loadedCategories.remove(categoryId);
    } else {
      _productsByCategory.clear();
      _loadedCategories.clear();
    }
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _products = [];
    _filteredProducts = [];
    _productsByCategory.clear();
    _loadedCategories.clear();
    _selectedProduct = null;
    _selectedCategoryId = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
