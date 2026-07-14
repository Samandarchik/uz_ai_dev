import 'package:flutter/foundation.dart';
// ================ SERVICES ================
// services/user_management_service.dart

import 'package:dio/dio.dart';

import 'package:uz_ai_dev/admin/model/user_model.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

class UserManagementService {
  final Dio dio = sl<Dio>();

  // Get all users - GET /api/users
  Future<List<User>> getAllUsers() async {
    try {
      final response = await dio.get(AppUrls.users);

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((e) => User.fromJson(e)).toList();
        } else {
          throw Exception(responseData['message'] ?? 'users_fetch_error');
        }
      } else {
        throw Exception('server_error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        // Body Map bo'lmasa (HTML 5xx, bo'sh javob) ham crash bo'lmasin.
        throw Exception(parseDioError(e,
            fallback: 'server_error: ${e.response!.statusCode}'));
      } else {
        throw Exception('network_error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Xatolik getAllUsers: $e');
      throw Exception('unexpected_error_users: $e');
    }
  }

  // Get single user by ID - GET /api/users/{id}
  Future<User?> getUserById(int id) async {
    try {
      final response = await dio.get('${AppUrls.users}/$id');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return User.fromJson(responseData['data']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('user_fetch_error: ${e.message}');
    } catch (e) {
      debugPrint('Xatolik getUserById: $e');
      throw Exception('unexpected_error_user: $e');
    }
  }

  // Create new user - POST /api/users
  Future<User> createUser(CreateUserRequest request) async {
    try {
      final response = await dio.post(
        AppUrls.register,
        data: request.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return User.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'user_create_error');
        }
      } else {
        throw Exception('server_error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = parseDioError(e, fallback: 'unknown_server_error');
        throw Exception('user_create_error: $errorMessage');
      } else {
        throw Exception('network_error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Xatolik createUser: $e');
      throw Exception('unexpected_error_create: $e');
    }
  }

  // Update user - PUT /api/users/{id}
  Future<User> updateUser(int id, UpdateUserRequest request) async {
    try {
      final response = await dio.put(
        '${AppUrls.users}/$id',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return User.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'user_update_error');
        }
      } else {
        throw Exception('server_error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('user_not_found');
        }
        final errorMessage = parseDioError(e, fallback: 'unknown_server_error');
        throw Exception('user_update_error: $errorMessage');
      } else {
        throw Exception('network_error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Xatolik updateUser: $e');
      throw Exception('unexpected_error_update: $e');
    }
  }

  // Delete user - DELETE /api/users/{id}
  Future<bool> deleteUser(int id) async {
    try {
      final response = await dio.delete('${AppUrls.users}/$id');

      if (response.statusCode == 200) {
        final responseData = response.data;
        return responseData['success'] == true;
      } else {
        return false;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('user_not_found');
        }
        final errorMessage = parseDioError(e, fallback: 'unknown_server_error');
        throw Exception('user_delete_error: $errorMessage');
      } else {
        throw Exception('network_error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Xatolik deleteUser: $e');
      throw Exception('unexpected_error_delete: $e');
    }
  }

  // Bitta foydalanuvchiga login+parolni Telegram orqali yuborish
  // POST /api/users/{id}/send-credentials
  Future<void> sendCredentials(int id) async {
    try {
      final response = await dio.post('${AppUrls.users}/$id/send-credentials');
      final responseData = response.data;
      if (responseData is Map && responseData['success'] == true) return;
      throw Exception(
          (responseData is Map ? responseData['message'] : null) ??
              'Telegram orqali yuborib bo\'lmadi');
    } on DioException catch (e) {
      if (e.response != null) {
        // 400 — Telegram bog'lanmagan, 502 — Telegram xatosi; backend
        // xabarini bevosita ko'rsatamiz.
        throw Exception(
            parseDioError(e, fallback: 'Telegram orqali yuborib bo\'lmadi'));
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // Barcha foydalanuvchilarga login+parolni Telegram orqali yuborish
  // POST /api/users/send-all-credentials
  Future<SendAllCredentialsResult> sendAllCredentials() async {
    try {
      final response = await dio.post(AppUrls.usersSendAllCredentials);
      final responseData = response.data;
      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
        final data = responseData['data'];
        return SendAllCredentialsResult.fromJson(
            data is Map<String, dynamic> ? data : const {});
      }
      throw Exception(
          (responseData is Map ? responseData['message'] : null) ??
              'Telegram orqali yuborib bo\'lmadi');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
            parseDioError(e, fallback: 'Telegram orqali yuborib bo\'lmadi'));
      }
      throw Exception('Tarmoq xatosi: ${e.message}');
    }
  }

  // Telegram bot username'i — GET /api/telegram-bot.
  // Xato bo'lsa standart bot nomi qaytadi (dialogdagi yo'riqnoma uchun).
  Future<String> getTelegramBotUsername() async {
    try {
      final response = await dio.get(AppUrls.telegramBot);
      final responseData = response.data;
      if (responseData is Map && responseData['success'] == true) {
        final username = (responseData['data'] as Map?)?['username'];
        if (username is String && username.isNotEmpty) return username;
      }
    } catch (_) {
      // Jim — fallback ishlatiladi.
    }
    return 'mone_order_bot';
  }

  // Helper methods
  Future<List<User>> getAdminUsers() async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => user.isAdmin).toList();
    } catch (e) {
      throw Exception('admin_users_error: $e');
    }
  }

  Future<List<User>> getRegularUsers() async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => !user.isAdmin).toList();
    } catch (e) {
      throw Exception('regular_users_error: $e');
    }
  }

  Future<User> toggleAdminStatus(int userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        throw Exception('user_not_found');
      }

      final updateRequest = UpdateUserRequest(isAdmin: !user.isAdmin);
      return await updateUser(userId, updateRequest);
    } catch (e) {
      throw Exception('toggle_admin_error: $e');
    }
  }
}

// services/filial_service.dart
class FilialService {
  final Dio dio = sl<Dio>();

  Future<List<Filial>> getAllFilials() async {
    try {
      final response = await dio.get(AppUrls.filials);

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((e) => Filial.fromJson(e)).toList();
        } else {
          throw Exception(responseData['message'] ?? 'filials_fetch_error');
        }
      } else {
        throw Exception('server_error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        // Body Map bo'lmasa (HTML 5xx, bo'sh javob) ham crash bo'lmasin.
        throw Exception(parseDioError(e,
            fallback: 'server_error: ${e.response!.statusCode}'));
      } else {
        throw Exception('network_error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Xatolik getAllFilials: $e');
      throw Exception('unexpected_error_filials: $e');
    }
  }
}
