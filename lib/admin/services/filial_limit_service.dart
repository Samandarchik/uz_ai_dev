// admin/services/filial_limit_service.dart — filial avto-buyurtma limitlari
// servisi (faqat admin): FilialLimitService.fetchLimits/saveLimit →
// GET/POST /api/filial-limits. limit_qty butun gr/ml (float yo'q).
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/filial_limit_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// Filial limitlari servisi (faqat admin, token global Dio interceptor
// orqali qo'shiladi). limit_qty birlik kontrakti: кг/л -> BUTUN gr/ml,
// шт va boshqalar -> oddiy butun son. Float YUBORILMAYDI.
class FilialLimitService {
  final Dio dio = sl<Dio>();

  // Bitta filialning limitlari (faqat limiti BOR mahsulotlar).
  Future<List<FilialLimit>> fetchLimits(int filialId) async {
    try {
      final response = await dio.get(
        AppUrls.filialLimits,
        queryParameters: {'filial_id': filialId},
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! List) return [];
      return data
          .map((e) => FilialLimit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // Limitni saqlaydi (upsert). limitQty = 0 — limitni O'CHIRADI.
  // Qaytadi: saqlangan qator; o'chirishda backend faqat message qaytaradi,
  // u holda null.
  Future<FilialLimit?> saveLimit({
    required int filialId,
    required int productId,
    required int limitQty,
  }) async {
    try {
      final response = await dio.post(
        AppUrls.filialLimits,
        data: {
          'filial_id': filialId,
          'product_id': productId,
          'limit_qty': limitQty,
        },
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return FilialLimit.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
