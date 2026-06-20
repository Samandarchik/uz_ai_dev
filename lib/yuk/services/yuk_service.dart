import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';

// Yuk keltiruvchi sklad buyurtmalari uchun Dio servis.
// Bearer token avtomatik ravishda Dio interceptor orqali qo'shiladi.
class YukService {
  final Dio dio = sl<Dio>();

  // GET /api/yuk/orders -> yuk keltiruvchiga biriktirilgan skladlarning
  // buyurtmalari. Javob: { "success": true, "message": "...", "data": [ ... ] }
  Future<List<YukOrder>> fetchOrders() async {
    try {
      final response = await dio.get(AppUrls.yukOrders);

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map) {
          return parseYukOrders(body['data']);
        }
        return [];
      } else {
        throw Exception('Buyurtmalarni yuklab bo\'lmadi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response!.data;
        final msg = (body is Map && body['message'] != null)
            ? body['message']
            : 'Server xatosi: ${e.response!.statusCode}';
        throw Exception(msg);
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    } catch (e) {
      throw Exception('Buyurtmalarni yuklashda kutilmagan xato: $e');
    }
  }
}
