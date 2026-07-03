import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';

// Bugalter (hisobchi) roli uchun Dio servis.
// Bearer token avtomatik ravishda Dio interceptor orqali qo'shiladi.
// Buyurtma JSON shakli yuk keltiruvchi buyurtmalari bilan bir xil,
// shuning uchun YukOrder modeli qayta ishlatiladi.
class BugalterService {
  final Dio dio = sl<Dio>();

  // GET /api/bugalter/orders -> BARCHA skladlarning narxlangan/qabul qilingan
  // buyurtmalari (yangisi tepada).
  // Javob: { "success": true, "data": [ {order}, ... ] }
  Future<List<YukOrder>> fetchOrders() async {
    try {
      final response = await dio.get(AppUrls.bugalterOrders);

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map) {
          return parseYukOrders(body['data']);
        }
        return [];
      }
      throw Exception('Buyurtmalarni yuklab bo\'lmadi: ${response.statusCode}');
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
