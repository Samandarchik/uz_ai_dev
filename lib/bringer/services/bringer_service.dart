import 'package:dio/dio.dart';
import 'package:uz_ai_dev/bringer/models/bringer_models.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class BringerService {
  final Dio dio = sl<Dio>();

  // ==================== BRINGER PROFILES ====================

  Future<List<BringerProfile>> getAllProfiles() async {
    try {
      final response = await dio.get(AppUrls.bringerProfiles);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => BringerProfile.fromJson(e)).toList();
      }
      throw Exception(response.data['message'] ?? 'Xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<BringerProfile?> getProfileById(int id) async {
    try {
      final response = await dio.get('${AppUrls.bringerProfiles}/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerProfile.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Future<BringerProfile> createProfile(BringerProfile profile) async {
    try {
      final response = await dio.post(
        AppUrls.bringerProfiles,
        data: profile.toCreateJson(),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerProfile.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Yaratishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<BringerProfile> updateProfile(int id, Map<String, dynamic> data) async {
    try {
      final response = await dio.put(
        '${AppUrls.bringerProfiles}/$id',
        data: data,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerProfile.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Yangilashda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<bool> deleteProfile(int id) async {
    try {
      final response = await dio.delete('${AppUrls.bringerProfiles}/$id');
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (_) {
      return false;
    }
  }

  // ==================== BRINGER ORDERS ====================
  // Backend endi tokendan avtomatik bringer_profile_id ni oladi

  Future<BringerOrder> createOrder() async {
    try {
      final response = await dio.post(AppUrls.bringerOrders);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerOrder.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Order yaratishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<List<BringerOrder>> getOrders() async {
    try {
      final response = await dio.get(AppUrls.bringerOrders);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => BringerOrder.fromJson(e)).toList();
      }
      throw Exception(response.data['message'] ?? 'Xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<BringerOrder?> getActiveOrder() async {
    try {
      final response = await dio.get(AppUrls.bringerOrdersActive);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerOrder.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Future<BringerOrder?> getOrderById(int id) async {
    try {
      final response = await dio.get('${AppUrls.bringerOrders}/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerOrder.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Future<BringerOrder> addOrderItem({
    required int productId,
    required double count,
    required int price,
    String? videoUrl,
    String? comment,
  }) async {
    try {
      final response = await dio.post(
        AppUrls.bringerOrderItems,
        data: {
          'product_id': productId,
          'count': count,
          'price': price,
          if (videoUrl != null) 'video_url': videoUrl,
          if (comment != null) 'comment': comment,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerOrder.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Item qo\'shishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<BringerOrder> pushOrder({String? comment}) async {
    try {
      final response = await dio.post(
        AppUrls.bringerOrderPush,
        data: {if (comment != null) 'comment': comment},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerOrder.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Order yuborishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<BringerOrder> deliverOrder(int orderId) async {
    try {
      final response = await dio.put(
        '${AppUrls.bringerOrders}/$orderId/deliver',
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerOrder.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Tasdiqlashda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  // ==================== BRINGER TASKS ====================

  Future<List<BringerTaskItem>> getTasks() async {
    try {
      final response = await dio.get(AppUrls.bringerTasks);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => BringerTaskItem.fromJson(e)).toList();
      }
      throw Exception(response.data['message'] ?? 'Xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  // ==================== BRINGER BALANCE ====================

  Future<BringerBalance?> getBalance() async {
    try {
      final response = await dio.get(AppUrls.bringerBalance);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerBalance.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Future<BringerBalance> addBalance({
    required int bringerProfileId,
    required int amount,
    String? comment,
  }) async {
    try {
      // Admin uchun — bringer_profile_id query param bilan
      final response = await dio.post(
        '${AppUrls.bringerBalanceAdd}?bringer_profile_id=$bringerProfileId',
        data: {
          'amount': amount,
          if (comment != null) 'comment': comment,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BringerBalance.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Balance qo\'shishda xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }

  Future<List<BringerTransaction>> getTransactions() async {
    try {
      final response = await dio.get(AppUrls.bringerTransactions);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => BringerTransaction.fromJson(e)).toList();
      }
      throw Exception(response.data['message'] ?? 'Xatolik');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Tarmoq xatosi');
    }
  }
}
