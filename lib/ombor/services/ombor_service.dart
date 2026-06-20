import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';

// Ombor (bozor) mahsulotlari uchun Dio servis.
// Bearer token avtomatik ravishda Dio interceptor orqali qo'shiladi.
class OmborService {
  final Dio dio = sl<Dio>();

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
}
