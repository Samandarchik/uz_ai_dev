// admin/services/api_printer_service.dart — printer registri CRUD servisi
// (ApiPrinterService): AppUrls.printers ga get/post/put/delete. Yozuv:
// {name, api_url, printer_no}. Chek yuborilganda backend shu registrdan
// kategoriya printerini topib, Excel faylni o'sha api_url ga yuboradi.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:uz_ai_dev/admin/model/print_device_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiPrinterService {
  final Dio dio = sl<Dio>();

  /// Backend Response envelope'idan xato matnini ajratib olish.
  String _messageOf(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (e.response != null) {
      return 'server_error: ${e.response!.statusCode}';
    }
    return 'network_error: ${e.message}';
  }

  Future<List<PrintDevice>> getPrinters() async {
    try {
      final response = await dio.get(AppUrls.printers);
      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map((e) => PrintDevice.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_messageOf(e));
    } catch (e) {
      debugPrint('getPrinters xato: $e');
      throw Exception('unexpected_error: $e');
    }
  }

  Future<PrintDevice> addPrinter({
    required String name,
    required String apiUrl,
    required int printerNo,
  }) async {
    try {
      final response = await dio.post(
        AppUrls.printers,
        data: {'name': name, 'api_url': apiUrl, 'printer_no': printerNo},
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return PrintDevice.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Kutilmagan javob shakli');
    } on DioException catch (e) {
      throw Exception(_messageOf(e));
    }
  }

  Future<PrintDevice> updatePrinter(
    int id, {
    required String name,
    required String apiUrl,
    required int printerNo,
  }) async {
    try {
      final response = await dio.put(
        '${AppUrls.printers}/$id',
        data: {'name': name, 'api_url': apiUrl, 'printer_no': printerNo},
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return PrintDevice.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Kutilmagan javob shakli');
    } on DioException catch (e) {
      throw Exception(_messageOf(e));
    }
  }

  Future<void> deletePrinter(int id) async {
    try {
      await dio.delete('${AppUrls.printers}/$id');
    } on DioException catch (e) {
      throw Exception(_messageOf(e));
    }
  }
}
