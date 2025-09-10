// services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'https://api.uz-dev-ai.uz';

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
      String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Server xatosi: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Login Error: $e');
      return {
        'success': false,
        'message': 'Internetga ulanishda xato: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getProducts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products'),
        headers: await _getHeaders(token: token),
      );

      print('Products Response Status: ${response.statusCode}');
      print('Products Response Body: ${response.body}');

      if (response.statusCode == 200) {
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
          'message': 'Mahsulotlarni yuklashda xato: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Products Error: $e');
      return {
        'success': false,
        'message': 'Internetga ulanishda xato: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createOrder(
      String token, Map<String, dynamic> orderData) async {
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
      return {
        'success': false,
        'message': 'Internetga ulanishda xato: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getOrders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders'),
        headers: await _getHeaders(token: token),
      );

      print('Get Orders Response Status: ${response.statusCode}');
      print('Get Orders Response Body: ${response.body}');

      if (response.statusCode == 200) {
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
          'message': 'Buyurtmalarni yuklashda xato: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Get Orders Error: $e');
      return {
        'success': false,
        'message': 'Internetga ulanishda xato: $e',
      };
    }
  }

  static Future<bool> deleteUser(String token) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/delete-user'),
      );
      return true;
    } catch (e) {
      return true;
    }
  }
}
