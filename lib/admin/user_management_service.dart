// ================ SERVICES ================
// services/user_management_service.dart

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/models/user_model.dart';

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
          throw Exception(responseData['message'] ?? 'users_fetch_error'.tr());
        }
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response!.data['message'] ??
            'server_error'.tr() + ': ${e.response!.statusCode}';
        throw Exception(errorMessage);
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik getAllUsers: $e');
      throw Exception('unexpected_error_users'.tr() + ': $e');
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
      throw Exception('user_fetch_error'.tr() + ': ${e.message}');
    } catch (e) {
      print('Xatolik getUserById: $e');
      throw Exception('unexpected_error_user'.tr() + ': $e');
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
          throw Exception(responseData['message'] ?? 'user_create_error'.tr());
        }
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('user_create_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik createUser: $e');
      throw Exception('unexpected_error_create'.tr() + ': $e');
    }
  }

  // Update user - PUT /api/users/{id}
  Future<User> updateUser(int id, UpdateUserRequest request) async {
    try {
      print(request.toJson());
      final response = await dio.put(
        '${AppUrls.users}/$id',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return User.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'user_update_error'.tr());
        }
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('user_not_found'.tr());
        }
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('user_update_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik updateUser: $e');
      throw Exception('unexpected_error_update'.tr() + ': $e');
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
          throw Exception('user_not_found'.tr());
        }
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('user_delete_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik deleteUser: $e');
      throw Exception('unexpected_error_delete'.tr() + ': $e');
    }
  }

  // Assign filial to user - PUT /api/users/{id}/assign-filial
  Future<User> assignFilialToUser(int userId, int filialId) async {
    try {
      final response = await dio.put(
        '${AppUrls.users}/$userId/assign-filial',
        data: AssignFilialRequest(filialId: filialId).toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          final user = await getUserById(userId);
          if (user != null) {
            return user;
          } else {
            throw Exception('updated_user_fetch_error'.tr());
          }
        } else {
          throw Exception(
              responseData['message'] ?? 'assign_filial_error'.tr());
        }
      } else {
        throw Exception('server_error'.tr() + ': ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          throw Exception('user_or_filial_not_found'.tr());
        }
        final errorMessage = e.response!.data['message'] ??
            e.response!.data['error'] ??
            'unknown_server_error'.tr();
        throw Exception('assign_filial_error'.tr() + ': $errorMessage');
      } else {
        throw Exception('network_error'.tr() + ': ${e.message}');
      }
    } catch (e) {
      print('Xatolik assignFilialToUser: $e');
      throw Exception('unexpected_error_assign'.tr() + ': $e');
    }
  }

  // Helper methods
  Future<List<User>> getUsersByFilial(int filialId) async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => user.filialId == filialId).toList();
    } catch (e) {
      throw Exception('users_by_filial_error'.tr() + ': $e');
    }
  }

  Future<List<User>> getAdminUsers() async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => user.isAdmin).toList();
    } catch (e) {
      throw Exception('admin_users_error'.tr() + ': $e');
    }
  }

  Future<List<User>> getRegularUsers() async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => !user.isAdmin).toList();
    } catch (e) {
      throw Exception('regular_users_error'.tr() + ': $e');
    }
  }

  Future<List<User>> searchUsers(String query) async {
    try {
      final allUsers = await getAllUsers();
      if (query.isEmpty) return allUsers;

      return allUsers.where((user) {
        final nameMatch = user.name.toLowerCase().contains(query.toLowerCase());
        final phoneMatch = user.phone.contains(query);
        return nameMatch || phoneMatch;
      }).toList();
    } catch (e) {
      throw Exception('search_users_error'.tr() + ': $e');
    }
  }

  Future<User> toggleAdminStatus(int userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        throw Exception('user_not_found'.tr());
      }

      final updateRequest = UpdateUserRequest(isAdmin: !user.isAdmin);
      return await updateUser(userId, updateRequest);
    } catch (e) {
      throw Exception('toggle_admin_error'.tr() + ': $e');
    }
  }
}
