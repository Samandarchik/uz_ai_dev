import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/filial_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiFilialService {
  final Dio dio = sl<Dio>();

  // Get all filials
  Future<List<Filial>> getFilials() async {
    try {
      final response = await dio.get(AppUrls.filials);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((e) => Filial.fromJson(e)).toList();
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
      print('Xatolik getFilials: $e');
      throw Exception('Kutilmagan xatolik: $e');
    }
  }

  // Get single filial by ID
  Future<Filial?> getFilialById(int id) async {
    try {
      final response = await dio.get('${AppUrls.filials}/$id');

      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        return Filial.fromJson(responseData);
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Filial olishda xatolik: ${e.message}');
    } catch (e) {
      print('Xatolik getFilialById: $e');
      throw Exception('Filial olishda kutilmagan xatolik: $e');
    }
  }
}
