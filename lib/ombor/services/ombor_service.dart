import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';

// Ombor (bozor) mahsulotlari uchun Dio servis.
// Bearer token avtomatik ravishda Dio interceptor orqali qo'shiladi.
class OmborService {
  final Dio dio = sl<Dio>();

  // POST /api/orders -> savatdagi mahsulotlarni buyurtma qilish.
  // items: [{"product_id": 1, "count": 5}, ...]
  // Javob: {"success": true, "message": "...", "data": {order}}
  Future<String> submitOrder(List<Map<String, dynamic>> items) async {
    try {
      final response = await dio.post(
        AppUrls.orders,
        data: {'items': items},
      );

      final status = response.statusCode ?? 0;
      final body = response.data;
      if (status >= 200 && status < 300) {
        if (body is Map && body['message'] != null) {
          return body['message'].toString();
        }
        return 'Buyurtma yuborildi';
      }
      throw Exception('Buyurtma yuborib bo\'lmadi: $status');
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
      throw Exception('Buyurtma yuborishda kutilmagan xato: $e');
    }
  }

  // GET /api/ombor/products -> source (manba) bo'yicha guruhlangan mahsulotlar.
  // Kalitlar: "samarqand", "toshkent", "zagranitsa", "boshqa".
  Future<Map<String, List<OmborProduct>>> fetchProducts() async {
    try {
      final response = await dio.get(AppUrls.omborProducts);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            Map<String, dynamic>.from(response.data);
        final data = responseData['data'];
        if (data is Map) {
          return parseOmborProducts(Map<String, dynamic>.from(data));
        }
        return {};
      } else {
        throw Exception('Mahsulotlarni yuklab bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Mahsulotlarni yuklashda kutilmagan xato: $e');
    }
  }

  // GET /api/orders -> ombor userning O'Z buyurtmalari ro'yxati.
  // Javob: {"success": true, "message": "...", "data": [ {order}, ... ]}
  Future<List<OmborOrder>> fetchMyOrders() async {
    try {
      final response = await dio.get(AppUrls.orders);

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map) {
          return parseOmborOrders(body['data']);
        }
        return <OmborOrder>[];
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

  // POST /api/orders/{id}/items/{productId}/accept -> BITTA mahsulotni
  // qabul qilish (kelgan soni + rasm/video). Kamida bitta rasm yoki video
  // majburiy (UI shuni tekshiradi). Order statusi created/narxlandi
  // bo'lsagina ishlaydi; hamma item qabul bo'lsa backend statusni
  // 'qabul_qilindi' qiladi.
  // Javob: {"success": true, "message": "...", "data": {to'liq yangilangan order}}
  Future<OmborOrder> acceptOrderItem(
    int orderId,
    int productId,
    double received,
    String? imagePath,
    String? videoPath,
  ) async {
    try {
      final form = FormData();
      form.fields.add(MapEntry('received', '$received'));
      if (imagePath != null) {
        form.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(imagePath),
        ));
      }
      if (videoPath != null) {
        form.files.add(MapEntry(
          'video',
          await MultipartFile.fromFile(videoPath),
        ));
      }
      final response = await dio.post(
        '${AppUrls.orders}/$orderId/items/$productId/accept',
        data: form,
      );
      final status = response.statusCode ?? 0;
      final body = response.data;
      if (status >= 200 && status < 300) {
        final data = (body is Map) ? body['data'] : null;
        if (data is Map) {
          return OmborOrder.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw Exception('Qabul qilib bo\'lmadi: $status');
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
      throw Exception('Qabul qilishda kutilmagan xato: $e');
    }
  }
}
