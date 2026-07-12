import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/yuk/models/yuk_ledger_model.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/models/yuk_transfer_model.dart';

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

  // GET /api/yuk/ledger/day?date=YYYY-MM-DD[&user_id=N] -> bitta kunning
  // xarajat tafsiloti: yuborilgan buyurtmalar (itemlari bilan) + o'sha kuni
  // yangilangan qoralamalar. Javob: { "success": true, "data": {...} }
  Future<LedgerDayDetail> fetchLedgerDay(String date, {int? userId}) async {
    try {
      final response = await dio.get(
        AppUrls.yukLedgerDay,
        queryParameters: {
          'date': date,
          if (userId != null) 'user_id': userId,
        },
      );

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return LedgerDayDetail.fromJson(
              Map<String, dynamic>.from(body['data']));
        }
        // Himoya: server data'siz to'g'ridan-to'g'ri obyekt qaytarsa ham o'qiymiz.
        if (body is Map && body['date'] != null) {
          return LedgerDayDetail.fromJson(Map<String, dynamic>.from(body));
        }
      }
      throw Exception('Kun tafsilotini yuklab bo\'lmadi: ${response.statusCode}');
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
      if (e is Exception) rethrow;
      throw Exception('Kun tafsilotini yuklashda kutilmagan xato: $e');
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

  // GET /api/yuk/transfers?status=pending -> targovli tizimidan yuborilgan
  // pullar (o'zimga tegishlilari). Javob: { "success": true, "data": [ ... ] }
  Future<List<YukTransfer>> fetchTransfers({String? status}) async {
    try {
      final response = await dio.get(
        AppUrls.yukTransfers,
        queryParameters: status == null ? null : {'status': status},
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map) return parseYukTransfers(body['data']);
        return [];
      }
      throw Exception('Pullarni yuklab bo\'lmadi: ${response.statusCode}');
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

  // POST /api/yuk/transfers/{id}/accept -> pulni qabul qilish. Server avval
  // targovli tizimini xabardor qiladi, keyin ledger'ga prixod yozadi.
  // POST /api/yuk/transfers/{id}/reject -> rad etish (sabab MAJBURIY).
  Future<YukTransfer?> decideTransfer(
    int id, {
    required bool accept,
    String reason = '',
  }) async {
    try {
      final response = await dio.post(
        '${AppUrls.yukTransfers}/$id/${accept ? 'accept' : 'reject'}',
        data: accept ? null : {'reason': reason},
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return YukTransfer.fromJson(Map<String, dynamic>.from(body['data']));
        }
        return null;
      }
      throw Exception('Saqlanmadi: ${response.statusCode}');
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

  // GET /api/ombor/products -> mahsulot id -> katalog rasmi (image_url, relativ)
  // xaritasi. Yuk keltiruvchining buyurtmadagi mahsulotlarining suratini
  // ko'rsatish uchun. Javob kategoriya bo'yicha guruhlangan:
  // { "data": { "Kategoriya": [ {"id":5, "image_url":"/static/..."}, ... ] } }.
  // Xato bo'lsa bo'sh xarita qaytadi — surat ekrani placeholder ko'rsatadi.
  Future<Map<int, String>> fetchBozorProductImages() async {
    try {
      final response = await dio.get(AppUrls.omborProducts);
      final result = <int, String>{};
      final body = response.data;
      final data = (body is Map) ? body['data'] : null;
      if (data is Map) {
        for (final list in data.values) {
          if (list is! List) continue;
          for (final item in list) {
            if (item is! Map) continue;
            final rawId = item['id'];
            final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
            final img = item['image_url'];
            if (id != null && img is String && img.isNotEmpty) {
              result[id] = img;
            }
          }
        }
      }
      return result;
    } on DioException {
      return <int, String>{};
    } catch (_) {
      return <int, String>{};
    }
  }
}
