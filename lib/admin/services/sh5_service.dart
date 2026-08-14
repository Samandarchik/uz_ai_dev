// admin/services/sh5_service.dart — SH5 (StoreHouse) qoldiq servisi (faqat
// admin, PLAN_OSTATKA bosqich 0): omborlar ro'yxati va bitta ombor tovarlari.
// Endpointlar: /api/sh5/remains[/{id}]. Javob envelope: {success, message, data}.
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/sh5_remain_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// SH5 qoldiq servisi (rk7_service naqshida, token global Dio interceptor
// orqali qo'shiladi). Faqat o'qish — POST yo'q.
class Sh5Service {
  final Dio dio = sl<Dio>();

  /// SH5 omborlari ro'yxati (nom bo'yicha tartiblangan, taken_at bilan).
  Future<List<Sh5RemainSklad>> fetchSklads() async {
    final data = await _get(AppUrls.sh5Remains);
    final raw = data is Map ? data['sklads'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Sh5RemainSklad.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Bitta ombor tovarlari; [q] — nom bo'yicha qidiruv (bo'sh = hammasi).
  Future<Sh5RemainDetail?> fetchDetail(int id, {String q = ''}) async {
    final query = q.trim();
    final data = await _get(
      AppUrls.sh5Remain(id),
      query: query.isEmpty ? null : {'q': query},
    );
    if (data is Map) {
      return Sh5RemainDetail.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<dynamic> _get(String url, {Map<String, dynamic>? query}) async {
    try {
      final response = await dio.get(url, queryParameters: query);
      return response.data is Map ? response.data['data'] : null;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
