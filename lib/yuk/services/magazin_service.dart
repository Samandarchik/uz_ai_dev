// yuk/services/magazin_service.dart — "Qarz daftari" Dio servisi: MagazinService.
// GET/POST/PUT/DELETE /api/magazins va /api/magazins/{id}/debts; rasm uchun /api/yuk/upload.
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/yuk/models/magazin_model.dart';

// Yuk keltiruvchining "Qarz daftari" (magazinlar va qarz yozuvlari) uchun
// Dio servis. Bearer token Dio interceptor orqali avtomatik qo'shiladi.
// Barcha javoblar { "success": bool, "message": "...", "data": ... } shaklida.
class MagazinService {
  final Dio dio = sl<Dio>();

  // Backend xato javobidan o'zbekcha message'ni ajratib Exception otish.
  Never _throwDio(DioException e) {
    if (e.response != null) {
      final body = e.response!.data;
      final msg = (body is Map && body['message'] != null)
          ? body['message'].toString()
          : 'Server xatosi: ${e.response!.statusCode}';
      throw Exception(msg);
    }
    throw Exception('Tarmoq xatosi: ${e.message}');
  }

  // GET /api/magazins -> data: { magazins: [...], total_debt: N }
  // total_debt — barcha magazinlar bo'yicha umumiy qarz.
  Future<({List<Magazin> magazins, double totalDebt})> fetchMagazins() async {
    try {
      final response = await dio.get(AppUrls.magazins);
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          final data = Map<String, dynamic>.from(body['data']);
          return (
            magazins: parseMagazins(data['magazins']),
            totalDebt: (data['total_debt'] as num?)?.toDouble() ?? 0,
          );
        }
        return (magazins: <Magazin>[], totalDebt: 0.0);
      }
      throw Exception('Magazinlarni yuklab bo\'lmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // POST /api/magazins -> data: yaratilgan magazin.
  Future<Magazin> createMagazin({
    required String name,
    required String shopName,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final response = await dio.post(AppUrls.magazins, data: {
        'name': name,
        'shop_name': shopName,
        'phone': phone,
        'image_url': imageUrl,
      });
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map &&
          response.data['data'] is Map) {
        return Magazin.fromJson(
            Map<String, dynamic>.from(response.data['data']));
      }
      throw Exception('Magazin saqlanmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // PUT /api/magazins/{id} -> data: yangilangan magazin.
  Future<Magazin> updateMagazin(
    int id, {
    required String name,
    required String shopName,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final response = await dio.put('${AppUrls.magazins}/$id', data: {
        'name': name,
        'shop_name': shopName,
        'phone': phone,
        'image_url': imageUrl,
      });
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is Map) {
        return Magazin.fromJson(
            Map<String, dynamic>.from(response.data['data']));
      }
      throw Exception('Magazin yangilanmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // DELETE /api/magazins/{id} — magazin va uning barcha qarz yozuvlarini
  // o'chiradi.
  Future<void> deleteMagazin(int id) async {
    try {
      final response = await dio.delete('${AppUrls.magazins}/$id');
      if (response.statusCode == 200) return;
      throw Exception('Magazin o\'chirilmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // GET /api/magazins/{id}/debts -> data: { magazin: {...}, debts: [...] }
  // debts eng yangisi birinchi; magazin ichida yangilangan total_debt keladi.
  Future<({Magazin? magazin, List<MagazinDebt> debts})> fetchDebts(
      int magazinId) async {
    try {
      final response = await dio.get('${AppUrls.magazins}/$magazinId/debts');
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is Map) {
          final data = Map<String, dynamic>.from(body['data']);
          return (
            magazin: data['magazin'] is Map
                ? Magazin.fromJson(Map<String, dynamic>.from(data['magazin']))
                : null,
            debts: parseMagazinDebts(data['debts']),
          );
        }
        return (magazin: null, debts: <MagazinDebt>[]);
      }
      throw Exception('Qarzlarni yuklab bo\'lmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // POST /api/magazins/{id}/debts -> data: yaratilgan qarz yozuvi.
  // amount nolga teng bo'lmasligi kerak; musbat — qarz qo'shish.
  Future<MagazinDebt> addDebt(
      int magazinId, double amount, String comment) async {
    try {
      final response = await dio.post(
        '${AppUrls.magazins}/$magazinId/debts',
        data: {'amount': amount, 'comment': comment},
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map &&
          response.data['data'] is Map) {
        return MagazinDebt.fromJson(
            Map<String, dynamic>.from(response.data['data']));
      }
      throw Exception('Qarz yozilmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // DELETE /api/magazins/{id}/debts/{debtId} — xato kiritilgan yozuvni
  // o'chirish.
  Future<void> deleteDebt(int magazinId, int debtId) async {
    try {
      final response =
          await dio.delete('${AppUrls.magazins}/$magazinId/debts/$debtId');
      if (response.statusCode == 200) return;
      throw Exception('Yozuv o\'chirilmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // POST /api/yuk/upload -> magazin rasmini yuklash (multipart, "file").
  // Javob: { "success": true, "data": { "url": "/static/yuk/<fayl>" } }
  // Mavjud yuk upload endpointi qayta ishlatiladi (YukService.uploadFile
  // bilan bir xil shakl).
  Future<String> uploadImage(String path) async {
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
      throw Exception('Rasm yuklanmadi: ${response.statusCode}');
    } on DioException catch (e) {
      _throwDio(e);
    }
  }
}
