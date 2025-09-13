// services/api_service.dart
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiAdminService {
 final Dio dio = sl<Dio>();
  static const String baseUrl = 'http://localhost:1010';




  Future<List<CategoryProduct>> getCategories() async {
    try {
      final response = await dio.get(AppUrls.category);

      return (response.data as List).map((e) => CategoryProduct.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }











  static Future<int> updateCategory(
      String token, CategoryProduct categoryData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/categories/${categoryData.id}'),
        headers: await _getHeaders(token: token),
        body: jsonEncode(categoryData),
      );
      return response.statusCode;
    } catch (e) {
      return 500;
    }
  } 


  

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

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Server xatosi: ${response.statusCode}',
        };
      }
    } catch (e) {
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

// 2-usul: Client tomonida tartibni o'zgartirish
  static Future<Map<String, dynamic>> getOrders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders'),
        headers: await _getHeaders(token: token),
      );
      print('Get Orders Response Status: ${response.statusCode}');
      print('Get Orders Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);

        // Agar 'data' yoki 'orders' kaliti mavjud bo'lsa
        if (result['data'] is List) {
          List orders = result['data'] as List;
          // Ro'yxatni teskari tartibda o'giramiz
          result['data'] = orders.reversed.toList();
        } else if (result['orders'] is List) {
          List orders = result['orders'] as List;
          result['orders'] = orders.reversed.toList();
        } else if (result is List) {
          // Agar natija to'g'ridan-to'g'ri ro'yxat bo'lsa
          result = {'data': (result as List).reversed.toList()};
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
