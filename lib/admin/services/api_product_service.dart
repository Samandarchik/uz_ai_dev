import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

class ApiProductService {
  final Dio dio = sl<Dio>();

  // Get all products
  Future<List<ProductModelAdmin>> getAllProducts() async {
    try {
      final response =
          await dio.get(AppUrls.productAll); // product/all endpoint

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((e) => ProductModelAdmin.fromJson(e)).toList();
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
            'Server xatosi: ${e.response!.statusCode} - ${e.response!.statusMessage}');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      debugPrint('Ошибка getAllProducts: $e');
      throw Exception('Kutilmagan Ошибка: $e');
    }
  }

  // Create new product
  Future<ProductModelAdmin> createProduct(ProductModelAdmin product) async {
    try {
      final response = await dio.post(
        AppUrls.product, // product endpoint
        data: product.toCreateJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        return ProductModelAdmin.fromJson(responseData);
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Mahsulot yaratishda Ошибка: ${parseDioError(e)}');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      debugPrint('Ошибка createProduct: $e');
      throw Exception('Mahsulot yaratishda kutilmagan Ошибка: $e');
    }
  }

  // Update existing product
  Future<ProductModelAdmin> updateProduct(ProductModelAdmin product) async {
    try {
      final response = await dio.put(
        '${AppUrls.product}/${product.id}',
        data: product.toUpdateJson(),
      );
      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        return ProductModelAdmin.fromJson(responseData);
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('Mahsulot topilmadi');
        }
        throw Exception('Mahsulot yangilashda Ошибка: ${parseDioError(e)}');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      throw Exception('Mahsulot yangilashda kutilmagan Ошибка: $e');
    }
  }

  // Delete product
  Future<ProductModelAdmin> deleteProduct(ProductModelAdmin product) async {
    try {
      final response = await dio.delete(
        '${AppUrls.product}/${product.id}',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.statusCode == 204 || response.data == null) {
          return product;
        } else {
          final responseData = response.data['data'] ?? response.data;
          return ProductModelAdmin.fromJson(responseData);
        }
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('Mahsulot topilmadi');
        } else if (e.response!.statusCode == 409) {
          throw Exception('Mahsulot o\'chirib bo\'lmaydi, u ishlatilmoqda');
        }
        throw Exception('Mahsulot o\'chirishda Ошибка: ${parseDioError(e)}');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      debugPrint('Ошибка deleteProduct: $e');
      throw Exception('Mahsulot o\'chirishda kutilmagan Ошибка: $e');
    }
  }

  // Reorder products by category
  Future<bool> reorderProducts(int categoryId, List<int> ids) async {
    try {
      final response = await dio.put(
        AppUrls.productReorder,
        data: {'category_id': categoryId, 'ids': ids},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Ошибка reorderProducts: $e');
      return false;
    }
  }
}
