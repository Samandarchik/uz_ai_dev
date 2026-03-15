import 'package:dio/dio.dart';
import 'package:uz_ai_dev/customer/models/customer_models.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class CustomerService {
  final Dio dio = sl<Dio>();

  // ==================== CUSTOMER ORDERS ====================

  Future<CustomerOrder> createOrder({
    required List<Map<String, dynamic>> items,
    String? comment,
  }) async {
    try {
      final response = await dio.post(
        AppUrls.customerOrders,
        data: {
          'items': items,
          if (comment != null) 'comment': comment,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CustomerOrder.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Buyurtma yaratishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<List<CustomerOrder>> getOrders() async {
    try {
      final response = await dio.get(AppUrls.customerOrders);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => CustomerOrder.fromJson(e)).toList();
      }
      throw Exception(response.data['message'] ?? 'Xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<CustomerOrder?> getOrderById(int id) async {
    try {
      final response = await dio.get('${AppUrls.customerOrders}/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CustomerOrder.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Future<CustomerOrder?> deleteOrderItem({
    required int orderId,
    required int productId,
    required double count,
  }) async {
    try {
      final response = await dio.delete(
        '${AppUrls.customerOrders}/$orderId/items',
        data: {
          'product_id': productId,
          'count': count,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['data'] != null) {
          return CustomerOrder.fromJson(response.data['data']);
        }
        return null; // Order was fully deleted
      }
      throw Exception(response.data['message'] ?? 'O\'chirishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<CustomerOrder> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await dio.put(
        '${AppUrls.customerOrders}/$orderId/status',
        data: {'status': status},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CustomerOrder.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Status yangilashda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }
}
