// admin/services/convert_pf_service.dart — takroriy bazalarni полуфабрикат
// mahsulotga aylantirish servisi: ConvertPfService.convert → POST
// /api/techcards/convert-pf (dry_run bilan; faqat admin).
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/convert_pf_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

// POST /api/techcards/convert-pf — takrorlangan bir xil bazalarni
// полуфабрикат mahsulotlarga aylantirish (faqat admin).
// dry_run=true — hech narsa o'zgarmaydi, faqat hisobot;
// dry_run=false — haqiqiy konvertatsiya.
class ConvertPfService {
  final Dio dio = sl<Dio>();

  Future<ConvertPfReport> convert({required bool dryRun}) async {
    try {
      final response = await dio.post(
        AppUrls.techcardsConvertPf,
        data: {'dry_run': dryRun},
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return ConvertPfReport.fromJson(
              Map<String, dynamic>.from(body['data']));
        }
        return const ConvertPfReport();
      }
      throw Exception('Server xatosi: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response!.data;
        final msg = (body is Map && body['message'] != null)
            ? body['message'].toString()
            : 'Server xatosi: ${e.response!.statusCode}';
        throw Exception(msg);
      }
      throw Exception('Tarmoq xatosi: ${e.message ?? 'ulanish yo\'q'}');
    }
  }
}
