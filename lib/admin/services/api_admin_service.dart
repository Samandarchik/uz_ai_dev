// ================ ADMIN SERVICES ================
// services/api_admin_service.dart

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiAdminService {
  final Dio dio = sl<Dio>();

  // Get all categories
  Future<List<CategoryProduct>> getCategories() async {
    try {
      final response = await dio.get(AppUrls.category);

      if (response.statusCode == 200) {
        // 'data' maydonini olish
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((e) => CategoryProduct.fromJson(e)).toList();
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
            'server_error'.tr() + ': ${e.response!.statusCode} - ${e.response!.statusMessage}');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik getCategories: $e');
      throw Exception('unexpected_error'.tr() + ': $e');
    }
  }

  // Create new category
  Future<CategoryProduct> createCategory(CategoryProduct category) async {
    try {
      final response = await dio.post(
        AppUrls.category,
        data: category.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Server 'data' maydonida qaytarishi mumkin yoki to'g'ridan-to'g'ri obyekt
        final responseData = response.data['data'] ?? response.data;
        return CategoryProduct.fromJson(responseData);
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('category_create_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik createCategory: $e');
      throw Exception('category_create_unexpected'.tr() + ': $e');
    }
  }

  // Update existing category
  Future<CategoryProduct> updateCategory(CategoryProduct category) async {
    try {
      final response = await dio.put(
        '${AppUrls.category}/${category.id}',
        data: category.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        return CategoryProduct.fromJson(responseData);
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('category_not_found'.tr());
        }
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('category_update_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik updateCategory: $e');
      throw Exception('category_update_unexpected'.tr() + ': $e');
    }
  }

  // Delete category
  Future<CategoryProduct> deleteCategory(CategoryProduct category) async {
    try {
      final response = await dio.delete(
        '${AppUrls.category}/${category.id}',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // DELETE so'rovidan keyin server bo'sh javob yoki o'chirilgan obyektni qaytarishi mumkin
        if (response.statusCode == 204 || response.data == null) {
          // Muvaffaqiyatli o'chirildi, original kategoriyani qaytaramiz
          return category;
        } else {
          final responseData = response.data['data'] ?? response.data;
          return CategoryProduct.fromJson(responseData);
        }
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('category_not_found'.tr());
        } else if (e.response!.statusCode == 409) {
          throw Exception('category_cannot_delete'.tr());
        }
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('category_delete_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik deleteCategory: $e');
      throw Exception('category_delete_unexpected'.tr() + ': $e');
    }
  }

  // Get single category by ID (optional method)
  Future<CategoryProduct?> getCategoryById(int id) async {
    try {
      final response = await dio.get('${AppUrls.category}/$id');

      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        return CategoryProduct.fromJson(responseData);
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('category_fetch_error'.tr() + ': ${e.message}');
    } catch (e) {
      print('Xatolik getCategoryById: $e');
      throw Exception('category_fetch_unexpected'.tr() + ': $e');
    }
  }
}
