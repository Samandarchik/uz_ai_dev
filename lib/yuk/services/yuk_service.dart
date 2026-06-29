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

  // PUT /api/yuk/orders/{id} -> buyurtmaga narx kiritib omborga qaytarish.
  // Body: { "items":[{"product_id":5,"taken":6,"subtotal":3000}, ...],
  //         "total":3000 }
  // Javob: { "success": true, "message": "...", "data": {order} }
  Future<void> priceOrder(
    int orderId,
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    try {
      final response = await dio.put(
        '${AppUrls.yukOrders}/$orderId',
        data: {
          'items': items,
          'total': total,
        },
      );

      if (response.statusCode == 200) {
        return;
      }
      throw Exception('Buyurtmani yuborib bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Buyurtmani yuborishda kutilmagan xato: $e');
    }
  }

  // PUT /api/yuk/orders/{id}/draft -> kiritilayotgan narxlarni (hali yubormasdan)
  // qoralama sifatida backendda saqlash. Status o'zgarmaydi. Body priceOrder
  // bilan bir xil. Ilovadan chiqib qayta kirilganda qiymatlar tiklanadi.
  Future<void> saveDraft(
    int orderId,
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final response = await dio.put(
      '${AppUrls.yukOrders}/$orderId/draft',
      data: {
        'items': items,
        'total': total,
      },
    );
    if (response.statusCode == 200) return;
    throw Exception('Qoralama saqlanmadi: ${response.statusCode}');
  }

  // POST /api/yuk/orders/{id}/revert -> yuborilgan buyurtmani qaytarib olish
  // (narxlangan -> qayta tahrirlanadigan holatga). Faqat ~30 soniya ichida.
  Future<void> revertOrder(int orderId) async {
    try {
      final response = await dio.post('${AppUrls.yukOrders}/$orderId/revert');
      if (response.statusCode == 200) {
        return;
      }
      throw Exception('Qaytarib olib bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Qaytarib olishda kutilmagan xato: $e');
    }
  }
}
