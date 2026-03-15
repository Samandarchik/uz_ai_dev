import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiService {
  static const String baseUrl = AppUrls.baseUrl;

  static Dio get _dio => sl<Dio>();

  // ────────────────────────── AUTH ──────────────────────────

  static Future<Map<String, dynamic>> login(
      String phone, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/login',
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

  static Future<Map<String, dynamic>> register() async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/login',
        data: {
          'phone': '+998770451117',
          'password': '293',
        },
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

  // ────────────────────────── PRODUCTS ──────────────────────────

  static Future<Map<String, dynamic>> getProducts(String token) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/products',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      print('Products DioException: ${e.message}');
      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Qaytadan login qiling!',
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

  // ────────────────────────── ORDERS ──────────────────────────

  static Future<Map<String, dynamic>> createOrder(
      String token, Map<String, dynamic> orderData) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/orders',
        data: orderData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      print('Order Response Status: ${response.statusCode}');
      print('Order Response Body: ${response.data}');

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      print('Order DioException: ${e.message}');
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

  static Future<Map<String, dynamic>> getOrders(String token,
      {int page = 1, int limit = 30}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/orders',
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

  static Future<Map<String, dynamic>> getAllOrders(String token) async {
    return getOrders(token, page: 1, limit: 1000);
  }

  // ────────────────────────── USER ──────────────────────────

  static Future<bool> deleteUser(String token) async {
    try {
      await _dio.delete(
        '$baseUrl/api/delete-user',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return true;
    } catch (e) {
      return true;
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
