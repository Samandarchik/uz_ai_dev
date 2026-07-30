// bugalter/services/bugalter_service.dart — Bugalter Dio servisi: BugalterService. Endpointlar
// AppUrls.bugalterOrders, yukUsers, bugalterOrderItemQty (PUT miqdor/summa), bugalterOrderItem
// (DELETE mahsulotni soft-delete), bugalterEdits (GET tahrirlar tarixi) va payments (POST to'lov);
// buyurtma JSON'i yuk keltiruvchiniki bilan bir xil, YukOrder modeli qayta ishlatiladi.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
// Tahrirlar tarixi audit yozuvlari — model admin audit jurnali bilan UMUMIY.
import 'package:uz_ai_dev/admin/model/audit_log_model.dart';
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
  // days/all — tarix oynasi: aktiv buyurtmalar har doim keladi, yopiqlari
  // esa faqat oxirgi `days` kun ichida (null — server default 30 kun,
  // all=true -> to'liq tarix).
  // Javob: { "success": true, "data": [ {order}, ... ] }
  Future<List<YukOrder>> fetchOrders({int? days, bool all = false}) async {
    try {
      final query = <String, dynamic>{};
      if (all) {
        query['all'] = 1;
      } else if (days != null) {
        query['days'] = days;
      }
      final response = await dio.get(
        AppUrls.bugalterOrders,
        queryParameters: query.isEmpty ? null : query,
      );

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

  // PUT /api/bugalter/orders/{orderId}/items/{productId}/qty ->
  // buyurtma ichidagi mahsulot miqdorini (gram xatolari) va/yoki SUMMASINI
  // tuzatish. Body: kamida bittasi — { "taken": 1500, "received": 1400,
  // "subtotal": 63000 }. received faqat alohida tahrirlansa yuboriladi
  // (yo'q bo'lsa server received == eski taken bo'lgan qabul qilingan itemda
  // o'zi sinxronlaydi); subtotal — BUTUN so'm (rasxod qatorida FAQAT shu
  // yuboriladi). Miqdorlar API birlikda (кг/л -> BUTUN gr/ml). Javob: to'liq
  // yangilangan buyurtma ({ "success": true, "message": "...", "data": {order} }).
  // Har bir o'zgargan maydon serverda audit jurnaliga yoziladi.
  Future<YukOrder> editItemQty({
    required int orderId,
    required int productId,
    num? taken,
    num? received,
    int? subtotal,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (taken != null) data['taken'] = taken;
      if (received != null) data['received'] = received;
      if (subtotal != null) data['subtotal'] = subtotal;

      final response = await dio.put(
        AppUrls.bugalterOrderItemQty(orderId, productId),
        data: data,
      );

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return YukOrder.fromJson(
              Map<String, dynamic>.from(body['data'] as Map));
        }
      }
      throw Exception(
          'Miqdorni yangilab bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Miqdorni yangilashda kutilmagan xato: $e');
    }
  }

  // DELETE /api/bugalter/orders/{orderId}/items/{productId} ->
  // buyurtma ichidagi mahsulotni o'chirish (soft-delete: serverda item
  // deleted=true bo'ladi, taken/subtotal/received nolga qaytariladi va
  // buyurtma jami summalari qayta hisoblanadi). Body yo'q. Javob: to'liq
  // yangilangan buyurtma ({ "success": true, "message": "...", "data": {order} }).
  // O'chirish serverda audit jurnaliga (field: "deleted") yoziladi.
  Future<YukOrder> deleteItem({
    required int orderId,
    required int productId,
  }) async {
    try {
      final response = await dio.delete(
        AppUrls.bugalterOrderItem(orderId, productId),
      );

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          return YukOrder.fromJson(
              Map<String, dynamic>.from(body['data'] as Map));
        }
      }
      throw Exception(
          'Mahsulotni o\'chirib bo\'lmadi: ${response.statusCode}');
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
      throw Exception('Mahsulotni o\'chirishda kutilmagan xato: $e');
    }
  }

  // GET /api/bugalter/edits[?order_id=&product_id=&limit=] -> tahrirlar
  // tarixi (kim, qachon, qaysi maydon, eski → yangi), eng yangisi birinchi.
  // orderId/productId berilmasa — barcha tahrirlar.
  // Javob: { "success": true, "data": [ {audit yozuvi}, ... ] }.
  Future<List<AuditLogEntry>> fetchEdits({
    int? orderId,
    int? productId,
    int limit = 100,
  }) async {
    try {
      final response = await dio.get(
        AppUrls.bugalterEdits,
        queryParameters: {
          'limit': limit,
          if (orderId != null) 'order_id': orderId,
          if (productId != null) 'product_id': productId,
        },
      );
      return AuditLogEntry.listFromJson(response.data);
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
      throw Exception('Tarixni yuklashda kutilmagan xato: $e');
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

  // GET /api/bugalter/export?from=YYYY-MM-DD&to=YYYY-MM-DD -> Excel (.xlsx)
  // hisobot (`to` kuni ham kiradi). Binar javob vaqtinchalik papkaga
  // yoziladi va faylning to'liq yo'li qaytariladi (UI share_plus bilan
  // ulashadi). Xatoda server JSON {success:false, message} qaytaradi.
  Future<String> downloadExport(DateTime from, DateTime to) async {
    final df = DateFormat('yyyy-MM-dd');
    final fromStr = df.format(from);
    final toStr = df.format(to);
    try {
      final response = await dio.get(
        AppUrls.bugalterExport,
        queryParameters: {'from': fromStr, 'to': toStr},
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200 && response.data is List) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/mone_hisobot_${fromStr}_$toStr.xlsx';
        final file = File(path);
        await file.writeAsBytes(
          List<int>.from(response.data as List),
          flush: true,
        );
        return path;
      }
      throw Exception('Hisobotni yuklab bo\'lmadi: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception(_exportErrorMessage(e));
    } catch (e) {
      throw Exception(
          e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ResponseType.bytes bilan kelgan xato javobi baytlarda bo'ladi —
  // ichidan JSON {message} ni ajratib olamiz (bo'lmasa umumiy matn).
  String _exportErrorMessage(DioException e) {
    final body = e.response?.data;
    if (body != null) {
      try {
        dynamic decoded = body;
        if (body is List<int>) decoded = jsonDecode(utf8.decode(body));
        if (decoded is Map && decoded['message'] != null) {
          return decoded['message'].toString();
        }
      } catch (_) {
        // JSON emas — pastdagi umumiy matnga tushamiz.
      }
    }
    if (e.response != null) {
      return 'Server xatosi: ${e.response!.statusCode}';
    }
    return 'Tarmoq xatosi: ${e.message}';
  }
}
