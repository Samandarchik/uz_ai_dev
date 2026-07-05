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

  // GET /api/ombor/products -> kategoriya bo'yicha guruhlangan mahsulotlar
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

  // GET /api/categories -> kategoriyalar ro'yxati (rasm + nom, server tartibida).
  // Admin paneldagi kabi kategoriya ro'yxatini ko'rsatish uchun.
  Future<List<OmborCategory>> fetchCategories() async {
    try {
      final response = await dio.get(AppUrls.category);

      if (response.statusCode == 200) {
        final body = response.data;
        final data = (body is Map) ? body['data'] : null;
        if (data is List) {
          return data
              .map((e) => OmborCategory.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return <OmborCategory>[];
      } else {
        throw Exception(
            'Kategoriyalarni yuklab bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Kategoriyalarni yuklashda kutilmagan xato: $e');
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

  // POST /api/orders/{id}/accept -> narxlangan buyurtmani qabul qilish.
  // Har bir mahsulot uchun rasm/video yuboriladi: multipart maydonlari
  // "image_<product_id>" va "video_<product_id>".
  // images/videos: product_id -> lokal fayl yo'li.
  // Javob: {"success": true, "message": "...", "data": {order}}
  Future<void> acceptOrder(
    int orderId,
    Map<int, double> received,
    Map<int, String> images,
    Map<int, String> videos,
  ) async {
    try {
      final form = FormData();
      for (final entry in received.entries) {
        form.fields.add(MapEntry('received_${entry.key}', '${entry.value}'));
      }
      for (final entry in images.entries) {
        form.files.add(MapEntry(
          'image_${entry.key}',
          await MultipartFile.fromFile(entry.value),
        ));
      }
      for (final entry in videos.entries) {
        form.files.add(MapEntry(
          'video_${entry.key}',
          await MultipartFile.fromFile(entry.value),
        ));
      }
      final response = await dio.post(
        '${AppUrls.orders}/$orderId/accept',
        data: form,
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return;
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
