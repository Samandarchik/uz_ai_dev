import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';
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

  // Yangi filial qo'shish (faqat superadmin). POST /api/filials
  // body {name, location}. Javob envelope: {success, message, data: filial}.
  Future<Filial> addFilial(String name, String location) async {
    try {
      final response = await dio.post(
        AppUrls.filials,
        data: {'name': name, 'location': location},
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return Filial.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Kutilmagan javob shakli');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // Filialni tahrirlash (faqat superadmin). PUT /api/filials/{id}
  // body {name, location}. Javob envelope: {success, message, data: filial}.
  Future<Filial> updateFilial(int id, String name, String location) async {
    try {
      final response = await dio.put(
        '${AppUrls.filials}/$id',
        data: {'name': name, 'location': location},
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return Filial.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Kutilmagan javob shakli');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // Filialni o'chirish (faqat superadmin). DELETE /api/filials/{id}.
  Future<void> deleteFilial(int id) async {
    try {
      await dio.delete('${AppUrls.filials}/$id');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
