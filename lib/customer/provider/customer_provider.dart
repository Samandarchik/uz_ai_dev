import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/customer/models/customer_models.dart';
import 'package:uz_ai_dev/customer/services/customer_service.dart';

// Customer uchun ProductModel (seller bilan bir xil)
class CustomerProductModel {
  final int id;
  final String name;
  final String? type;
  final num? grams;
  final String? category;
  final String? ingredients;
  final String? imageUrl;
  final int? bringerId;

  CustomerProductModel({
    required this.id,
    required this.name,
    this.ingredients,
    this.type,
    this.grams,
    this.category,
    this.imageUrl,
    this.bringerId,
  });

  factory CustomerProductModel.fromJson(Map<String, dynamic> json) {
    return CustomerProductModel(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      grams: json['grams'],
      ingredients: json['ingredients'],
      category: json['category'],
      imageUrl: json['image_url'],
      bringerId: json['bringer_id'],
    );
  }
}

// Customer uchun CategoryModel (seller bilan bir xil)
class CustomerCategoryModel {
  final int id;
  final String name;
  final int printer;
  final String? imageUrl;

  CustomerCategoryModel({
    required this.id,
    required this.name,
    required this.printer,
    this.imageUrl,
  });

  factory CustomerCategoryModel.fromJson(Map<String, dynamic> json) {
    return CustomerCategoryModel(
      id: json['id'],
      name: json['name'],
      printer: json['printer'],
      imageUrl: json['image_url'],
    );
  }
}

class CustomerProvider extends ChangeNotifier {
  final CustomerService _orderService = CustomerService();
  final Dio _dio = sl<Dio>();

  // Mahsulotlar (seller bilan bir xil tuzilma)
  Map<String, List<CustomerProductModel>> productsByCategory = {};
  List<CustomerCategoryModel> categories = [];
  Map<int, double> selectedProducts = {}; // productId: quantity
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  // Buyurtmalar
  List<CustomerOrder> _orders = [];
  List<CustomerOrder> get orders => _orders;

  // ==================== KATEGORIYALAR ====================

  Future<void> fetchCategories() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get(AppUrls.category);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        categories =
            data.map((item) => CustomerCategoryModel.fromJson(item)).toList();
      }
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  // ==================== MAHSULOTLAR ====================

  Future<void> fetchProducts() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get(AppUrls.product1);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data['data'];

        productsByCategory = {};
        data.forEach((category, products) {
          if (products is List) {
            productsByCategory[category] = products
                .map((item) => CustomerProductModel.fromJson(item))
                .toList();
          }
        });
      }
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  List<CustomerProductModel> getProductsByCategory(String category) {
    return productsByCategory[category] ?? [];
  }

  double getProductQuantity(int productId) {
    return selectedProducts[productId] ?? 0.0;
  }

  // Increment miqdori (seller bilan bir xil)
  double _getIncrementAmount(int productId) {
    CustomerProductModel? product;
    for (var products in productsByCategory.values) {
      try {
        product = products.firstWhere((p) => p.id == productId);
        break;
      } catch (e) {
        continue;
      }
    }
    if (product != null && product.type != null) {
      num? grams = product.grams;
      return grams?.toDouble() ?? 1.0;
    }
    return 1.0;
  }

  double _roundToPrecision(double value, int decimals) {
    double mod = 1.0;
    for (int i = 0; i < decimals; i++) {
      mod *= 10;
    }
    return (value * mod).round() / mod;
  }

  void incrementProduct(int productId) {
    double amount = _getIncrementAmount(productId);
    double newValue = (selectedProducts[productId] ?? 0.0) + amount;
    selectedProducts[productId] = _roundToPrecision(newValue, 3);
    notifyListeners();
  }

  void decrementProduct(int productId) {
    if (selectedProducts.containsKey(productId)) {
      double amount = _getIncrementAmount(productId);
      double newQuantity = selectedProducts[productId]! - amount;
      newQuantity = _roundToPrecision(newQuantity, 3);
      if (newQuantity > 0) {
        selectedProducts[productId] = newQuantity;
      } else {
        selectedProducts.remove(productId);
      }
      notifyListeners();
    }
  }

  void setProductQuantity(int productId, double quantity) {
    if (quantity > 0) {
      selectedProducts[productId] = quantity;
    } else {
      selectedProducts.remove(productId);
    }
    notifyListeners();
  }

  double get totalSelectedProducts {
    return selectedProducts.values.fold(0.0, (sum, qty) => sum + qty);
  }

  void clearSelection() {
    selectedProducts.clear();
    notifyListeners();
  }

  // ==================== BUYURTMA YUBORISH ====================
  // Customer order - /api/customer/orders ga yuboriladi
  Future<void> submitOrder() async {
    isSubmitting = true;
    notifyListeners();

    try {
      final items = selectedProducts.entries.map((entry) {
        return {
          'product_id': entry.key,
          'count': entry.value,
        };
      }).toList();

      await _orderService.createOrder(items: items);
      clearSelection();
    } catch (e) {
      throw Exception('Buyurtma yuborishda xatolik: $e');
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== BUYURTMALAR TARIXI ====================

  Future<void> loadOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _orders = await _orderService.getOrders();
      _orders = _orders.reversed.toList();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> deleteOrderItem({
    required int orderId,
    required int productId,
    required double count,
  }) async {
    try {
      final updatedOrder = await _orderService.deleteOrderItem(
        orderId: orderId,
        productId: productId,
        count: count,
      );
      if (updatedOrder != null) {
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) _orders[index] = updatedOrder;
      } else {
        _orders.removeWhere((o) => o.id == orderId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      final updated = await _orderService.updateOrderStatus(orderId, status);
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) _orders[index] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
