import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/product.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

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
      print('Xatolik getAllProducts: $e');
      throw Exception('Kutilmagan xatolik: $e');
    }
  }

  // Get products by category ID
  Future<List<ProductModelAdmin>> getProductsByCategoryId(
      int categoryId) async {
    try {
      final response = await dio.get(AppUrls.productAll);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        final List<ProductModelAdmin> allProducts =
            data.map((e) => ProductModelAdmin.fromJson(e)).toList();

        // Filter products by category_id
        return allProducts
            .where((product) => product.categoryId == categoryId)
            .toList();
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
      print('Xatolik getProductsByCategoryId: $e');
      throw Exception('Kutilmagan xatolik: $e');
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
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'Noma\'lum server xatosi';
        throw Exception('Mahsulot yaratishda xatolik: $errorMessage');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('Xatolik createProduct: $e');
      throw Exception('Mahsulot yaratishda kutilmagan xatolik: $e');
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
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'Noma\'lum server xatosi';
        throw Exception('Mahsulot yangilashda xatolik: $errorMessage');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('Xatolik updateProduct: $e');
      throw Exception('Mahsulot yangilashda kutilmagan xatolik: $e');
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
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'Noma\'lum server xatosi';
        throw Exception('Mahsulot o\'chirishda xatolik: $errorMessage');
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('Xatolik deleteProduct: $e');
      throw Exception('Mahsulot o\'chirishda kutilmagan xatolik: $e');
    }
  }

  // Get single product by ID
  Future<ProductModelAdmin?> getProductById(int id) async {
    try {
      final response = await dio.get('${AppUrls.product}/$id');

      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        return ProductModelAdmin.fromJson(responseData);
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Mahsulot olishda xatolik: ${e.message}');
    } catch (e) {
      print('Xatolik getProductById: $e');
      throw Exception('Mahsulot olishda kutilmagan xatolik: $e');
    }
  }
}
