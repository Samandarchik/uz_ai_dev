import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/yuk/models/yuk_ledger_model.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';

// Yuk keltiruvchi sklad buyurtmalari uchun Dio servis.
// Bearer token avtomatik ravishda Dio interceptor orqali qo'shiladi.
class YukService {
  final Dio dio = sl<Dio>();

  // GET /api/yuk/orders -> yuk keltiruvchiga biriktirilgan skladlarning
  // buyurtmalari. Javob: { "success": true, "message": "...", "data": [ ... ] }
  // status: 'pending' — faqat yuborilmaganlar (asosiy sahifa),
  //         'done'    — faqat yuborilganlar (tarix ekrani), null — hammasi.
  Future<List<YukOrder>> fetchOrders({String? status}) async {
    try {
      final response = await dio.get(
        AppUrls.yukOrders,
        queryParameters: status == null ? null : {'status': status},
      );

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

  // GET /api/yuk/ledger -> yuk keltiruvchining kunlik hisob daftari.
  // Javob: { "success": true, "data": [ {date,opening,prixod,rasxod,closing} ] }
  // Kunlar backenddan kamayuvchi tartibda (eng yangi kun birinchi) keladi.
  Future<List<YukLedgerDay>> fetchLedger() async {
    try {
      final response = await dio.get(AppUrls.yukLedger);

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map) {
          return parseYukLedger(body['data']);
        }
        return [];
      }
      throw Exception('Hisobni yuklab bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Hisobni yuklashda kutilmagan xato: $e');
    }
  }

  // POST /api/yuk/upload -> rasm yoki video faylni yuklash (multipart, "file").
  // Javob: { "success": true, "data": { "url": "/static/yuk/<fayl>" } }
  // Qaytgan relativ URL priceOrder'ning attachments ro'yxatiga qo'shiladi.
  Future<String> uploadFile(String path) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path),
      });
      final response = await dio.post(AppUrls.yukUpload, data: form);
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          final url = body['data']['url']?.toString() ?? '';
          if (url.isNotEmpty) return url;
        }
      }
      throw Exception('Fayl yuklanmadi: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response!.data;
        final msg = (body is Map && body['message'] != null)
            ? body['message']
            : 'Server xatosi: ${e.response!.statusCode}';
        throw Exception(msg);
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // PUT /api/yuk/orders/{id} -> buyurtmaga narx kiritib omborga qaytarish.
  // Body: { "items":[{"product_id":5,"taken":6,"subtotal":3000}, ...],
  //         "total":3000, "attachments":["/static/yuk/x.jpg", ...],
  //         "added_items":[{"item_type":"proche","name":"...","taken":1,
  //                         "subtotal":300000}, ...] }
  // total — mahsulotlar summasi (katalog + proche), rasxod KIRMAYDI.
  // Javob: { "success": true, "message": "...", "data": {order} }
  // Yangilangan buyurtmani qaytaradi (lokal ro'yxatni refetch'siz yangilash uchun).
  Future<YukOrder?> priceOrder(
    int orderId,
    List<Map<String, dynamic>> items,
    double total, {
    List<String> attachments = const [],
    List<Map<String, dynamic>> addedItems = const [],
  }) async {
    try {
      final response = await dio.put(
        '${AppUrls.yukOrders}/$orderId',
        data: {
          'items': items,
          'total': total,
          'attachments': attachments,
          'added_items': addedItems,
        },
      );

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return YukOrder.fromJson(Map<String, dynamic>.from(body['data']));
        }
        return null;
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
    double total, {
    List<Map<String, dynamic>> addedItems = const [],
  }) async {
    final response = await dio.put(
      '${AppUrls.yukOrders}/$orderId/draft',
      data: {
        'items': items,
        'total': total,
        // Qo'shilgan proche/rasxod itemlar — ledger'dagi Rasxod real time
        // yangilanishi uchun qoralamada ham yuboriladi.
        'added_items': addedItems,
      },
    );
    if (response.statusCode == 200) return;
    throw Exception('Qoralama saqlanmadi: ${response.statusCode}');
  }

  // POST /api/yuk/orders/{id}/revert -> yuborilgan buyurtmani qaytarib olish
  // (narxlangan -> qayta tahrirlanadigan holatga). Faqat ~30 soniya ichida.
  // Yangilangan (pending) buyurtmani qaytaradi.
  Future<YukOrder?> revertOrder(int orderId) async {
    try {
      final response = await dio.post('${AppUrls.yukOrders}/$orderId/revert');
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return YukOrder.fromJson(Map<String, dynamic>.from(body['data']));
        }
        return null;
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
