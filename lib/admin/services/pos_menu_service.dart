import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/pos_menu_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// POS (Konak) menyu servisi (faqat admin, token global Dio interceptor
// orqali qo'shiladi). Javob envelope: {success, message, data}.
class PosMenuService {
  final Dio dio = sl<Dio>();

  // POS ko'radigan katalog: kategoriyalar + mahsulotlar. filialId
  // berilmasa server birinchi filialni oladi.
  Future<PosMenuResult> fetchPosMenu({int? filialId}) async {
    try {
      final response = await dio.get(
        AppUrls.posMenu,
        queryParameters: {
          if (filialId != null) 'filial_id': filialId,
        },
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return PosMenuResult.fromJson(Map<String, dynamic>.from(data));
      }
      return const PosMenuResult();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
