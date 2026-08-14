// admin/services/rk7_service.dart — RK7 integratsiyasi servisi (faqat admin):
// smenalar (import logi), bog'lanmagan taomlar, mapping va sotuv nuqtalari.
// Endpointlar: /api/rk7/shifts[/{id}], /api/rk7/unmapped, /api/rk7/mappings,
// /api/rk7/sale-places. Javob envelope: {success, message, data}.
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/rk7_mapping_model.dart';
import 'package:uz_ai_dev/admin/model/rk7_sale_place_model.dart';
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

// RK7 servisi (pos_sale_service naqshida, token global Dio interceptor
// orqali qo'shiladi). Serverga float yuborilmaydi: per_portion — int,
// pul — butun so'm, miqdor — qty_milli (butun).
class Rk7Service {
  final Dio dio = sl<Dio>();

  // ─────────────────────────── Smenalar (import) ───────────────────────────

  /// Oxirgi [days] kunlik import qilingan smenalar (eng yangisi birinchi).
  /// days serverda clamp [1,92].
  Future<List<Rk7Shift>> fetchShifts({int days = 30}) async {
    final data = await _get(AppUrls.rk7Shifts, query: {'days': days});
    return rk7ListFrom(_pick(data, 'shifts'), Rk7Shift.fromJson);
  }

  /// Bitta smena to'liq: items/voids/deductions/unmapped.
  Future<Rk7Shift?> fetchShift(int id) async {
    final data = await _get(AppUrls.rk7Shift(id));
    final raw = data is Map && data['shift'] is Map ? data['shift'] : data;
    if (raw is Map) return Rk7Shift.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }

  // ─────────────────────────── Mapping (taomlar) ───────────────────────────

  /// Sotuvda uchragan, lekin Mone mahsulotiga bog'lanmagan taomlar.
  Future<List<Rk7UnmappedDish>> fetchUnmapped() async {
    final data = await _get(AppUrls.rk7Unmapped);
    return rk7ListFrom(_pick(data, 'unmapped'), Rk7UnmappedDish.fromJson);
  }

  /// Mapping ro'yxati; [q] — taom nomi/kodi bo'yicha qidiruv (bo'sh = hammasi).
  Future<List<Rk7Mapping>> fetchMappings({String q = ''}) async {
    final query = q.trim();
    final data = await _get(
      AppUrls.rk7Mappings,
      query: query.isEmpty ? null : {'q': query},
    );
    return rk7ListFrom(_pick(data, 'mappings'), Rk7Mapping.fromJson);
  }

  /// Mapping upsert. perPortion — BUTUN son (float yuborilmaydi).
  Future<Rk7Mapping?> saveMapping({
    required String dishGuid,
    required int productId,
    required String deductMode,
    required int perPortion,
    bool active = true,
  }) async {
    final data = await _post(AppUrls.rk7Mappings, {
      'dish_guid': dishGuid,
      'product_id': productId,
      'deduct_mode': deductMode,
      'per_portion': perPortion,
      'active': active,
    });
    final raw = data is Map && data['mapping'] is Map ? data['mapping'] : data;
    if (raw is Map) return Rk7Mapping.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }

  // ────────────────────────── Sotuv nuqtalari ──────────────────────────

  /// Barcha RK7 sotuv nuqtalari (mapping holati bilan).
  Future<List<Rk7SalePlace>> fetchSalePlaces() async {
    final data = await _get(AppUrls.rk7SalePlaces);
    return rk7ListFrom(_pick(data, 'sale_places'), Rk7SalePlace.fromJson);
  }

  /// Sotuv nuqtasi upsert: filial va sklad bog'lanishi.
  Future<Rk7SalePlace?> saveSalePlace({
    required String uotGuid,
    required int filialId,
    required int skladId,
    bool active = true,
  }) async {
    final data = await _post(AppUrls.rk7SalePlaces, {
      'uot_guid': uotGuid,
      'filial_id': filialId,
      'sklad_id': skladId,
      'active': active,
    });
    final raw =
        data is Map && data['sale_place'] is Map ? data['sale_place'] : data;
    if (raw is Map) {
      return Rk7SalePlace.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  // ─────────────────────────────── Ichki ───────────────────────────────

  // Envelope {success, message, data} dan `data` ni oladi; xatoni o'qiladigan
  // matnga o'giradi (pos/filial servislaridagi naqsh).
  Future<dynamic> _get(String url, {Map<String, dynamic>? query}) async {
    try {
      final response = await dio.get(url, queryParameters: query);
      return response.data is Map ? response.data['data'] : null;
    } on DioException catch (e) {
      throw _asException(e);
    }
  }

  Future<dynamic> _post(String url, Map<String, dynamic> body) async {
    try {
      final response = await dio.post(url, data: body);
      return response.data is Map ? response.data['data'] : null;
    } on DioException catch (e) {
      throw _asException(e);
    }
  }

  Exception _asException(DioException e) {
    if (e.response != null) {
      return Exception('Server xatosi: ${parseDioError(e)}');
    }
    return Exception('Tarmoq xatosi: ${e.message}');
  }

  // `data` massiv bo'lsa o'zi, obyekt bo'lsa [key] ostidagi massiv.
  dynamic _pick(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map) return data[key];
    return null;
  }
}
