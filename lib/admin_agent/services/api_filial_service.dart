import 'package:dio/dio.dart';

import 'package:uz_ai_dev/admin_agent/model/user_model.dart';
import 'package:uz_ai_dev/core/agent/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiFilialService {
  final Dio dio = sl<Dio>();

  // Get all filials
  Future<List<Filial>> getFilials() async {
    try {
      final response = await dio.get(AppUrlsAgent.filials);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((e) => Filial.fromJson(e)).toList();
      } else {
        throw Exception('server_error' + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          'server_error' +
              ': ${e.response!.statusCode} - ${e.response!.statusMessage}',
        );
      } else {
        throw Exception('network_error' + ': ${e.message}');
      }
    } catch (e) {
      print('Ошибка getFilials: $e');
      throw Exception('unexpected_error' + ': $e');
    }
  }

  // Get single filial by ID
  Future<Filial?> getFilialById(int id) async {
    try {
      final response = await dio.get('${AppUrlsAgent.filials}/$id');

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
      throw Exception('filial_fetch_error' + ': ${e.message}');
    } catch (e) {
      print('Ошибка getFilialById: $e');
      throw Exception('filial_fetch_unexpected' + ': $e');
    }
  }
}
