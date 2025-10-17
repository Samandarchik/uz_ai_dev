// services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:uz_ai_dev/core/constants/urls.dart';

class ApiServiceAgent {
  static const String baseUrl = AppUrls.baseUrl;

  static Future<Map<String, String>> _getHeaders({String? token}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: await _getHeaders(),
        body: jsonEncode({'phone': phone, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Server xatosi: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Internetga ulanishda xato: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProducts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products'),
        headers: await _getHeaders(token: token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Qaytadan login qiling!',
          'needLogin': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Mahsulotlarni yuklashda xato: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Products Error: $e');
      return {'success': false, 'message': 'Internetga ulanishda xato: $e'};
    }
  }

  static Future<Map<String, dynamic>> createOrder(
    String token,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: await _getHeaders(token: token),
        body: jsonEncode(orderData),
      );

      print('Order Response Status: ${response.statusCode}');
      print('Order Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Token yaroqsiz. Qaytadan kiring.',
          'needLogin': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Buyurtma yaratishda xato: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Order Error: $e');
      return {'success': false, 'message': 'Internetga ulanishda xato: $e'};
    }
  }

  // Pagination bilan buyurtmalarni olish
  static Future<Map<String, dynamic>> getOrders(
    String token, {
    int page = 1,
    int limit = 30,
  }) async {
    try {
      // URL ga pagination parametrlarini qo'shamiz
      String url = '$baseUrl/api/orders?page=$page&limit=$limit';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(token: token),
      );

      print('Get Orders Response Status: ${response.statusCode}');
      print('Get Orders Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);

        // Response formatiga qarab ma'lumotlarni qayta ishlash
        if (result['data'] is List) {
          // Ma'lumotlarni teskari tartibda qaytaramiz (yangi buyurtmalar birinchi bo'lsin)
          List orders = result['data'] as List;
          result['data'] = orders.reversed.toList();
        } else if (result['orders'] is List) {
          List orders = result['orders'] as List;
          result['orders'] = orders.reversed.toList();
        } else if (result is List) {
          // Agar natija to'g'ridan-to'g'ri ro'yxat bo'lsa
          List orders = result as List;
          result = {
            'success': true,
            'data': orders.reversed.toList(),
            'current_page': page,
            'per_page': limit,
            'total': orders.length,
            'last_page': 1,
          };
        }

        // Pagination ma'lumotlarini qo'shamiz (agar server tomonida yo'q bo'lsa)
        if (!result.containsKey('current_page')) {
          result['current_page'] = page;
        }
        if (!result.containsKey('per_page')) {
          result['per_page'] = limit;
        }
        if (!result.containsKey('last_page')) {
          result['last_page'] = 1;
        }
        if (!result.containsKey('total')) {
          result['total'] = (result['data'] as List?)?.length ?? 0;
        }

        return result;
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Token yaroqsiz. Qaytadan kiring.',
          'needLogin': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Buyurtmalarni yuklashda xato: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Get Orders Error: $e');
      return {'success': false, 'message': 'Internetga ulanishda xato: $e'};
    }
  }

  // Barcha buyurtmalarni birdan olish (eski usul - backward compatibility uchun)
  static Future<Map<String, dynamic>> getAllOrders(String token) async {
    return getOrders(token, page: 1, limit: 1000); // Katta limit bilan
  }

  static Future<bool> deleteUser(String token) async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/delete-user'));
      return true;
    } catch (e) {
      return true;
    }
  }
}
