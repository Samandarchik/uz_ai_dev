import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin_agent/model/product_model.dart';
import 'package:uz_ai_dev/admin_agent/services/api_product_service.dart';

class ProductProviderAgentAdmin extends ChangeNotifier {
  final ApiProductService _service = ApiProductService();

  // Barcha mahsulotlar bir marta yuklanadi
  List<ProductModelAdmin> _allProducts = [];
  List<ProductModelAdmin> _filteredProducts = [];

  bool _isLoading = false;
  bool _isInitialized = false; // Ma'lumotlar yuklangani
  String? _error;
  ProductModelAdmin? _selectedProduct;
  int? _selectedCategoryId;

  // Getters
  List<ProductModelAdmin> get products => _allProducts;
  List<ProductModelAdmin> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  ProductModelAdmin? get selectedProduct => _selectedProduct;
  int? get selectedCategoryId => _selectedCategoryId;

  // Barcha mahsulotlarni bir marta yuklash
  Future<void> initializeProducts({bool forceRefresh = false}) async {
    // Agar allaqachon yuklangan bo'lsa va force refresh yo'q bo'lsa, qayta yuklamaymiz
    if (_isInitialized && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allProducts = await _service.getAllProducts();
      _filteredProducts = _allProducts;
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isInitialized = false;
      notifyListeners();
    }
  }

  // Kategoriya bo'yicha filter (internetga murojaat qilmasdan)
  void filterByCategory(int categoryId) {
    _selectedCategoryId = categoryId;
    _filteredProducts = _allProducts
        .where((product) => product.categoryId == categoryId)
        .toList();
    notifyListeners();
  }

  // Barcha mahsulotlarni ko'rsatish
  void showAllProducts() {
    _selectedCategoryId = null;
    _filteredProducts = _allProducts;
    notifyListeners();
  }

  // Get all products (eski metod, mos kelish uchun)
  Future<void> getAllProducts({bool forceRefresh = false}) async {
    await initializeProducts(forceRefresh: forceRefresh);
  }

  // Get products by category ID (optimized - filterdan foydalanadi)
  Future<void> getProductsByCategoryId(
    int categoryId, {
    bool forceRefresh = false,
  }) async {
    // Agar ma'lumotlar yuklanmagan bo'lsa, avval yuklaymiz
    if (!_isInitialized || forceRefresh) {
      await initializeProducts(forceRefresh: forceRefresh);
    }

    // Keyin filter qilamiz
    filterByCategory(categoryId);
  }

  // Create new product
  Future<bool> createProduct(ProductModelAdmin product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newProduct = await _service.createProduct(product);

      // Barcha mahsulotlar ro'yxatiga qo'shish
      _allProducts.add(newProduct);

      // Agar hozirgi filter mos kelsa, filtered listga ham qo'shamiz
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

      // Barcha mahsulotlar ro'yxatida yangilash
      final index = _allProducts.indexWhere((p) => p.id == updatedProduct.id);
      if (index != -1) {
        _allProducts[index] = updatedProduct;
      }

      // Filtered listda yangilash
      final filteredIndex = _filteredProducts.indexWhere(
        (p) => p.id == updatedProduct.id,
      );
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

      // Barcha ro'yxatlardan o'chirish
      _allProducts.removeWhere((p) => p.id == product.id);
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
    // Avval local datadan qidiramiz
    try {
      final localProduct = _allProducts.firstWhere((p) => p.id == id);
      _selectedProduct = localProduct;
      notifyListeners();
      return localProduct;
    } catch (e) {
      // Agar local datada bo'lmasa, serverdan olamiz
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
  }

  // Set selected product
  void setSelectedProduct(ProductModelAdmin? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  // Clear filter
  void clearFilter() {
    _selectedCategoryId = null;
    _filteredProducts = _allProducts;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Kategoriya bo'yicha mahsulotlar sonini olish
  int getProductCountByCategory(int categoryId) {
    return _allProducts.where((p) => p.categoryId == categoryId).length;
  }

  // Clear all data
  void clear() {
    _allProducts = [];
    _filteredProducts = [];
    _selectedProduct = null;
    _selectedCategoryId = null;
    _error = null;
    _isLoading = false;
    _isInitialized = false;
    notifyListeners();
  }
}
