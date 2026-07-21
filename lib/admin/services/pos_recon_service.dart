// admin/services/pos_recon_service.dart — Konak POS smena solishtiruvi servisi
// (faqat admin): PosReconService.fetchPosRecons → GET /api/pos-recons?days=N.
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/pos_recon_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// POS (Konak) smena solishtirish servisi (faqat admin, token global Dio
// interceptor orqali qo'shiladi). Javob envelope: {success, message, data}.
class PosReconService {
  final Dio dio = sl<Dio>();

  // Oxirgi [days] kunlik solishtiruv yozuvlari (eng yangisi birinchi).
  // days default 30 (serverda clamp [1,92]).
  Future<PosReconsResult> fetchPosRecons({int days = 30, int? filialId}) async {
    try {
      final response = await dio.get(
        AppUrls.posRecons,
        queryParameters: {
          'days': days,
          if (filialId != null) 'filial_id': filialId,
        },
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return PosReconsResult.fromJson(Map<String, dynamic>.from(data));
      }
      return const PosReconsResult();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
