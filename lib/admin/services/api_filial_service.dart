import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/admin/model/user_model.dart';

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
        throw Exception('server_error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('server_error: ${e.response!.statusCode} - ${e.response!.statusMessage}');
      } else {
        throw Exception('network_error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Ошибка getFilials: $e');
      throw Exception('unexpected_error: $e');
    }
  }
}
