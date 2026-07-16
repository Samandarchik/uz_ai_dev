import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/audit_log_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// Audit jurnali servisi: GET /api/audit-log (faqat admin, token global
// Dio interceptor orqali qo'shiladi).
class AuditLogService {
  final Dio dio = sl<Dio>();

  // Jurnal yozuvlari (eng yangisi birinchi). entity berilsa — faqat shu
  // obyekt turi bo'yicha filtr (product/stock/order/magazin_debt/payment).
  Future<List<AuditLogEntry>> fetchAuditLog({
    String? entity,
    int limit = 100,
  }) async {
    try {
      final response = await dio.get(
        AppUrls.auditLog,
        queryParameters: {
          'limit': limit,
          if (entity != null && entity.isNotEmpty) 'entity': entity,
        },
      );
      return AuditLogEntry.listFromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
