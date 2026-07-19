import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/pos_order_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// POS (Konak) buyurtmalari servisi (faqat admin, token global Dio
// interceptor orqali qo'shiladi). Javob envelope: {success, message, data}.
class PosOrderService {
  final Dio dio = sl<Dio>();

  // «POS avto» buyurtmalari, eng yangisi birinchi.
  Future<List<PosOrder>> fetchPosOrders({int limit = 50}) async {
    try {
      final response = await dio.get(
        AppUrls.posOrders,
        queryParameters: {'limit': limit},
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => PosOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Server xatosi: ${parseDioError(e)}');
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // Buyurtmani bazadan POS'ga yuborish. Muvaffaqiyatda yaratilgan
  // PosDelivery qaytadi (ro'yxat joyida yangilanadi, re-fetch YO'Q).
  // Allaqachon yuborilgan bo'lsa server 409 qaytaradi — message'i
  // parseDioError orqali chiqadi.
  Future<PosDelivery> dispatchOrder(int orderId) async {
    try {
      final response = await dio.post(AppUrls.posOrderDispatch(orderId));
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map) {
        return PosDelivery.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Kutilmagan server javobi');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(parseDioError(e));
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }
}
