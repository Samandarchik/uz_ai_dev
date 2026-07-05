import 'package:dio/dio.dart';
import 'package:uz_ai_dev/bugalter/models/yuk_user_model.dart';
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

  // GET /api/yuk-users -> yuk keltiruvchi foydalanuvchilar ro'yxati
  // (pul berish dialogidagi dropdown uchun).
  // Javob: { "success": true, "data": [ {id,name,phone}, ... ] }
  Future<List<YukUser>> fetchYukUsers() async {
    try {
      final response = await dio.get(AppUrls.yukUsers);

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map) {
          return parseYukUsers(body['data']);
        }
        return [];
      }
      throw Exception(
          'Foydalanuvchilarni yuklab bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Foydalanuvchilarni yuklashda kutilmagan xato: $e');
    }
  }

  // POST /api/payments -> yuk keltiruvchiga pul berish (prixod yozuvi).
  // Body: { "user_id":37, "amount":500000, "comment":"..." }
  // Muvaffaqiyatda backenddan kelgan message qaytariladi.
  Future<String> createPayment({
    required int userId,
    required int amount,
    String comment = '',
  }) async {
    try {
      final response = await dio.post(
        AppUrls.payments,
        data: {
          'user_id': userId,
          'amount': amount,
          'comment': comment,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map && body['message'] != null) {
          return body['message'].toString();
        }
        return 'Pul berildi';
      }
      throw Exception('Pul berib bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Pul berishda kutilmagan xato: $e');
    }
  }
}
