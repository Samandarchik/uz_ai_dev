import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiService {
  static Dio get _dio => sl<Dio>();

  // ────────────────────────── AUTH ──────────────────────────

  static Future<Map<String, dynamic>> login(
      String phone, String password) async {
    try {
      final response = await _dio.post(
        AppUrls.login,
        data: {
          'phone': phone,
          'password': password,
        },
      );

      print('Login Response: ${response.data}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      print('Login DioException: ${e.message}');
      print('Login Response Body: ${e.response?.data}');
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Kutilmagan xato: $e',
      };
    }
  }

  /// v1 login — FAQAT parol bilan kirish. Javob shakli eski login bilan
  /// bir xil (token + user).
  static Future<Map<String, dynamic>> loginV1(String password) async {
    try {
      final response = await _dio.post(
        AppUrls.loginV1,
        data: {'password': password},
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Kutilmagan xato: $e',
      };
    }
  }

  // ────────────────────────── ORDERS ──────────────────────────

  static Future<Map<String, dynamic>> getOrders(String token,
      {int page = 1, int limit = 30}) async {
    try {
      final response = await _dio.get(
        AppUrls.orders,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      print('Get Orders Response Status: ${response.statusCode}');
      print('Get Orders Response Body: ${response.data}');

      Map<String, dynamic> result = Map<String, dynamic>.from(response.data);

      // Response formatiga qarab ma'lumotlarni qayta ishlash
      if (result['data'] is List) {
        List orders = result['data'] as List;
        result['data'] = orders.reversed.toList();
      } else if (result['orders'] is List) {
        List orders = result['orders'] as List;
        result['orders'] = orders.reversed.toList();
      }

      // Pagination ma'lumotlarini qo'shamiz (agar server tomonida yo'q bo'lsa)
      result.putIfAbsent('current_page', () => page);
      result.putIfAbsent('per_page', () => limit);
      result.putIfAbsent('last_page', () => 1);
      result.putIfAbsent('total', () => (result['data'] as List?)?.length ?? 0);

      return result;
    } on DioException catch (e) {
      print('Get Orders DioException: ${e.message}');
      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Token yaroqsiz. Qaytadan kiring.',
          'needLogin': true,
        };
      }
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Kutilmagan xato: $e',
      };
    }
  }

  // ────────────────────────── ERROR HANDLER ──────────────────────────

  static String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Server bilan ulanish vaqti tugadi';
      case DioExceptionType.sendTimeout:
        return 'Ma\'lumot yuborishda vaqt tugadi';
      case DioExceptionType.receiveTimeout:
        return 'Server javob bermadi';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        if (body is Map && body['message'] != null) {
          return '${body['message']}';
        }
        return 'Server xatosi: $statusCode';
      case DioExceptionType.cancel:
        return 'So\'rov bekor qilindi';
      case DioExceptionType.connectionError:
        return 'Internetga ulanib bo\'lmadi';
      default:
        return 'Internetga ulanishda xato: ${e.message}';
    }
  }
}
