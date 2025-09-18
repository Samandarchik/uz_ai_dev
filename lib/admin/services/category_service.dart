// services/filial_service.dart
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/models/user_model.dart';

class CategoryService {
  final Dio dio = sl<Dio>();

  Future<List<CategoryProduct>> getAllCategorys() async {
    try {
      final response = await dio.get(AppUrls.category);

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((e) => CategoryProduct.fromJson(e)).toList();
        } else {
          throw Exception(
              responseData['message'] ?? 'categories_fetch_error'.tr());
        }
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response!.data['message'] ??
            'server_error'.tr() + ': ${e.response!.statusCode}';
        throw Exception(errorMessage);
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik getAllFilials: $e');
      throw Exception('unexpected_error_filials'.tr() + ': $e');
    }
  }

  Future<Filial?> getFilialById(int id) async {
    try {
      final response = await dio.get('${AppUrls.filials}/$id');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return Filial.fromJson(responseData['data']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('categories_fetch_error'.tr() + ': ${e.message}');
    } catch (e) {
      print('Xatolik getFilialById: $e');
      throw Exception('unexpected_error_filial'.tr() + ': $e');
    }
  }
}
