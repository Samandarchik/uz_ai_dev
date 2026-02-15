import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ProductModel {
  final int id;
  final String name;
  final String? type;
  final num? grams;
  final String? category;
  final String? ingredients;
  final String? imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    this.ingredients,
    this.type,
    this.grams,
    this.category,
    this.imageUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      grams: json['grams'],
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

  OrderItem({
    required this.productId,
    required this.count,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'count': count,
    };
  }
}

class ProductProvider extends ChangeNotifier {
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
      num? grams = product.grams;
      return grams?.toDouble() ?? 1.0; // 1 gram = 0.001 kg
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

  // Buyurtmani print bo'yicha guruhlash va yuborish
  Future<void> submitOrder() async {
    isSubmitting = true;
    notifyListeners();

    try {
      // Print bo'yicha guruhlash
      Map<int, List<OrderItem>> ordersByPrint = {};

      selectedProducts.forEach((productId, count) {
        int printNumber = productPrintMap[productId] ?? 1;

        if (!ordersByPrint.containsKey(printNumber)) {
          ordersByPrint[printNumber] = [];
        }

        ordersByPrint[printNumber]!.add(
          OrderItem(
            productId: productId,
            count: count,
          ),
        );
      });

      // Print raqami bo'yicha tartiblash (1, 2, 3...)
      List<int> sortedPrintNumbers = ordersByPrint.keys.toList()..sort();

      // Har bir print uchun ketma-ket yuborish
      final service = ProductService();
      for (int printNumber in sortedPrintNumbers) {
        List<OrderItem> items = ordersByPrint[printNumber]!;

        Map<String, dynamic> orderData = {
          'items': items.map((item) => item.toJson()).toList(),
        };

        await service.submitOrder(orderData);

        // Keyingi printerga yuborishdan oldin biroz kutish
        if (printNumber != sortedPrintNumbers.last) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      // Muvaffaqiyatli yuborilgandan keyin tozalash
      clearSelection();
    } catch (e) {
      throw Exception('Buyurtma yuborishda xatolik: $e');
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}

class ProductService {
  Dio dio = sl<Dio>();

  // Kategoriyalarni olish
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await dio.get(AppUrls.category);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((item) => CategoryModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  // Mahsulotlarni olish
  Future<Map<String, dynamic>> fetchProducts() async {
    try {
      final response = await dio.get(AppUrls.product1);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = response.data;
        final Map<String, dynamic> data = responseData['data'];

        Map<String, List<ProductModel>> productsByCategory = {};
        Map<int, int> productPrintMap = {};

        // Kategoriyalarni olish va print raqamini aniqlash
        final categoriesResponse = await fetchCategories();
        Map<String, int> categoryPrintMap = {};

        for (var category in categoriesResponse) {
          categoryPrintMap[category.name] = category.print;
        }

        data.forEach((category, products) {
          if (products is List) {
            int printNumber = categoryPrintMap[category] ?? 1;

            List<ProductModel> productList =
                products.map((item) => ProductModel.fromJson(item)).toList();

            productsByCategory[category] = productList;

            // Har bir mahsulot uchun print raqamini saqlash
            for (var product in productList) {
              productPrintMap[product.id] = printNumber;
            }
          }
        });

        return {
          'products': productsByCategory,
          'printMap': productPrintMap,
        };
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }

  // Buyurtma yuborish
  Future<void> submitOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await dio.post(
        AppUrls.orders,
        data: orderData,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to submit order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit order: $e');
    }
  }
}
