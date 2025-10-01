import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/product.dart';
import 'package:uz_ai_dev/admin/services/api_product_service.dart';

// ==================== PRODUCT PROVIDER ====================
class ProductProviderAdmin extends ChangeNotifier {
  final ApiProductService _service = ApiProductService();

  List<ProductModelAdmin> _products = [];
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

  // Get products by category ID
  Future<void> getProductsByCategoryId(int categoryId) async {
    _isLoading = true;
    _error = null;
    _selectedCategoryId = categoryId;
    notifyListeners();

    try {
      _filteredProducts = await _service.getProductsByCategoryId(categoryId);
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

  // Clear all data
  void clear() {
    _products = [];
    _filteredProducts = [];
    _selectedProduct = null;
    _selectedCategoryId = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
