import 'package:flutter/material.dart';
import 'package:uz_ai_dev/user_agent/services/product_service.dart';

class ProductModel {
  final int id;
  final String name;
  final String? type;
  final String? category;
  final String? ingredients;
  final String? imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    this.ingredients,
    this.type,
    this.category,
    this.imageUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      ingredients: json['ingredients'],
      category: json['category'],
      imageUrl: json['image_url'],
    );
  }
}

// Category Model
class CategoryModel {
  final int id;
  final String name;
  final int print;
  final String? imageUrl;

  CategoryModel({
    required this.id,
    required this.name,
    required this.print,
    this.imageUrl,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      print: json['printer'],
      imageUrl: json['image_url'],
    );
  }
}

// Order Item Model
class OrderItem {
  final int productId;
  final double count; // int -> double

  OrderItem({required this.productId, required this.count});

  Map<String, dynamic> toJson() {
    return {'product_id': productId, 'count': count};
  }
}

class ProductProviderAgent extends ChangeNotifier {
  Map<String, List<ProductModel>> productsByCategory = {};
  List<CategoryModel> categories = [];
  Map<int, double> selectedProducts = {}; // productId: quantity (double)
  Map<int, int> productPrintMap = {}; // productId: print number
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;
  final service = ProductService();

  // Kategoriyalarni yuklash
  Future<void> fetchCategories() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      categories = await service.fetchCategories();
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  // Mahsulotlarni yuklash
  Future<void> fetchProducts() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final service = ProductService();
      final result = await service.fetchProducts();
      productsByCategory = result['products'];
      productPrintMap = result['printMap'];
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  List<ProductModel> getProductsByCategory(String category) {
    return productsByCategory[category] ?? [];
  }

  double getProductQuantity(int productId) {
    return selectedProducts[productId] ?? 0.0;
  }

  // Product type bo'yicha increment miqdorini aniqlash
  double _getIncrementAmount(int productId) {
    // Mahsulot type ni topish
    ProductModel? product;
    for (var products in productsByCategory.values) {
      try {
        product = products.firstWhere((p) => p.id == productId);
        break;
      } catch (e) {
        continue;
      }
    }

    if (product != null && product.type != null) {
      String type = product.type!.toLowerCase();
      if (type.contains('гр') || type.contains('gr') || type.contains('gram')) {
        return 0.001; // 1 gram = 0.001 kg
      }
    }
    return 1.0; // Default: Кг uchun
  }

  // Floating point precision muammosini hal qilish
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

  Future<void> submitOrder(
      String token, String comment, DateTime sentDataTime) async {
    isSubmitting = true;
    notifyListeners();

    try {
      // Tanlangan mahsulotlarni oddiy tarzda yuborish
      final service = ProductService();

      // Order uchun JSON ma'lumot tayyorlash
      Map<String, dynamic> orderData = {
        'items': selectedProducts.entries.map((entry) {
          return {
            'product_id': entry.key,
            'count': entry.value,
            "comment": comment,
            "sent_data_time": sentDataTime.toIso8601String(),
          };
        }).toList(),
      };

      // Backendga yuborish
      await service.submitOrder(orderData);

      // Yuborilgandan so‘ng tozalash
      clearSelection();
    } catch (e) {
      throw Exception('Buyurtma yuborishda xatolik: $e');
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
