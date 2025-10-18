import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/agent/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/user_agent/provider/provider.dart';

class ProductService {
  Dio dio = sl<Dio>();

  // Kategoriyalarni olish
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await dio.get(AppUrlsAgent.category);

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
      final response = await dio.get(AppUrlsAgent.product1);

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

        return {'products': productsByCategory, 'printMap': productPrintMap};
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
      final response = await dio.post(AppUrlsAgent.orders, data: orderData);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to submit order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit order: $e');
    }
  }
}
