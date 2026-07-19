import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/pos_sale_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// POS (Konak) smena sotuvlari servisi (faqat admin, token global Dio
// interceptor orqali qo'shiladi). Javob envelope: {success, message, data}.
class PosSaleService {
  final Dio dio = sl<Dio>();

  // Oxirgi [days] kunlik sotuv hisobotlari (eng yangisi birinchi) +
  // umumiy summa. days default 30 (serverda clamp [1,92]).
  Future<PosSalesResult> fetchPosSales({int days = 30, int? filialId}) async {
    try {
      final response = await dio.get(
        AppUrls.posSales,
        queryParameters: {
          'days': days,
          if (filialId != null) 'filial_id': filialId,
        },
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return PosSalesResult.fromJson(Map<String, dynamic>.from(data));
      }
      return const PosSalesResult();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
