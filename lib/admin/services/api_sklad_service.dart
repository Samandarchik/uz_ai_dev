// admin/services/api_sklad_service.dart — sklad (omborxona) CRUD servisi
// (ApiSkladService): AppUrls.sklads ga get/post/put/delete
// (getSklads/addSklad/updateSklad/deleteSklad). Yozish endpointlari backendda
// requireSuperAdmin bilan himoyalangan.
import 'package:dio/dio.dart';

import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/data/sklad_registry.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/models/sklad_model.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

class ApiSkladService {
  final Dio dio = sl<Dio>();

  // GET /api/sklads — ro'yxat (hamma rol o'qiy oladi).
  Future<List<Sklad>> getSklads() async {
    try {
      return await SkladRegistry.fetch();
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // POST /api/sklads, body {name}. Javob: {success, message, data: sklad}.
  Future<Sklad> addSklad(String name) async {
    try {
      final response = await dio.post(AppUrls.sklads, data: {'name': name});
      return _parse(response);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // PUT /api/sklads/{id}, body {name}.
  Future<Sklad> updateSklad(int id, String name) async {
    try {
      final response =
          await dio.put('${AppUrls.sklads}/$id', data: {'name': name});
      return _parse(response);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // DELETE /api/sklads/{id}. Sklad ishlatilayotgan bo'lsa server 400 va
  // sababni qaytaradi (foydalanuvchi/mahsulot biriktirilgan, qoldiq bor...).
  Future<void> deleteSklad(int id) async {
    try {
      await dio.delete('${AppUrls.sklads}/$id');
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  Sklad _parse(Response response) {
    final data = response.data is Map ? response.data['data'] : null;
    if (data is Map) {
      return Sklad.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Kutilmagan javob shakli');
  }

  String _message(DioException e) => e.response != null
      ? parseDioError(e)
      : 'Tarmoq xatosi: ${e.message ?? ''}';
}
