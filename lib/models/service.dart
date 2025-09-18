import 'package:dio/dio.dart';
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
          throw Exception(
              responseData['message'] ?? 'Foydalanuvchilarni olishda xatolik');
        }
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response!.data['message'] ??
            'Server xatosi: ${e.response!.statusCode}';
        throw Exception(errorMessage);
      } else {
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('Xatolik getAllUsers: $e');
      throw Exception('Foydalanuvchilarni olishda kutilmagan xatolik: $e');
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
      throw Exception('Foydalanuvchi olishda xatolik: ${e.message}');
    } catch (e) {
      print('Xatolik getUserById: $e');
      throw Exception('Foydalanuvchi olishda kutilmagan xatolik: $e');
    }
  }

  // Create new user - POST /api/register
  Future<User> createUser(CreateUserRequest request) async {
    try {
      print('Creating user with data: ${request.toJson()}'); // Debug log

      final response = await dio.post(
        AppUrls.register, // POST /api/register endpoint
        data: request.toJson(),
      );

      print('Register response status: ${response.statusCode}'); // Debug log
      print('Register response data: ${response.data}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return User.fromJson(responseData['data']);
        } else {
          // Success false bo'lganda message ni ko'rsatish
          final errorMessage =
              responseData['message'] ?? 'Foydalanuvchi yaratishda xatolik';
          print('Register error message: $errorMessage');
          throw Exception(errorMessage);
        }
      } else {
        // Status code 200 bo'lmasa
        final responseData = response.data;
        final errorMessage =
            responseData['message'] ?? 'Server xatosi: ${response.statusCode}';
        print('Register status error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      print('DioException in createUser: ${e.toString()}'); // Debug log

      if (e.response != null) {
        print('Error response data: ${e.response!.data}'); // Debug log

        // Response ichidagi message ni olish
        dynamic responseData = e.response!.data;
        String errorMessage;

        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              'Server xatosi: ${e.response!.statusCode}';
        } else {
          errorMessage = 'Server xatosi: ${e.response!.statusCode}';
        }

        print('Parsed error message: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('Network error: ${e.message}');
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('General error in createUser: $e');
      throw Exception('Foydalanuvchi yaratishda kutilmagan xatolik: $e');
    }
  }

  // Update user - PUT /api/users/{id}
  Future<User> updateUser(int id, UpdateUserRequest request) async {
    try {
      print('Updating user $id with data: ${request.toJson()}'); // Debug log

      final response = await dio.put(
        '${AppUrls.users}/$id',
        data: request.toJson(),
      );

      print('Update response status: ${response.statusCode}'); // Debug log
      print('Update response data: ${response.data}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          return User.fromJson(responseData['data']);
        } else {
          final errorMessage =
              responseData['message'] ?? 'Foydalanuvchi yangilashda xatolik';
          print('Update error message: $errorMessage');
          throw Exception(errorMessage);
        }
      } else {
        final responseData = response.data;
        final errorMessage =
            responseData['message'] ?? 'Server xatosi: ${response.statusCode}';
        print('Update status error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      print('DioException in updateUser: ${e.toString()}'); // Debug log

      if (e.response != null) {
        print('Update error response data: ${e.response!.data}'); // Debug log

        if (e.response!.statusCode == 404) {
          throw Exception('Foydalanuvchi topilmadi');
        }

        dynamic responseData = e.response!.data;
        String errorMessage;

        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              'Server xatosi: ${e.response!.statusCode}';
        } else {
          errorMessage = 'Server xatosi: ${e.response!.statusCode}';
        }

        print('Parsed update error message: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('Update network error: ${e.message}');
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('General error in updateUser: $e');
      throw Exception('Foydalanuvchi yangilashda kutilmagan xatolik: $e');
    }
  }

  // Delete user - DELETE /api/users/{id}
  Future<bool> deleteUser(int id) async {
    try {
      print('Deleting user with id: $id'); // Debug log

      final response = await dio.delete('${AppUrls.users}/$id');

      print('Delete response status: ${response.statusCode}'); // Debug log
      print('Delete response data: ${response.data}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = response.data;
        return responseData['success'] == true;
      } else {
        return false;
      }
    } on DioException catch (e) {
      print('DioException in deleteUser: ${e.toString()}'); // Debug log

      if (e.response != null) {
        print('Delete error response data: ${e.response!.data}'); // Debug log

        if (e.response!.statusCode == 404) {
          throw Exception('Foydalanuvchi topilmadi');
        }

        dynamic responseData = e.response!.data;
        String errorMessage;

        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              'Server xatosi: ${e.response!.statusCode}';
        } else {
          errorMessage = 'Server xatosi: ${e.response!.statusCode}';
        }

        print('Parsed delete error message: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('Delete network error: ${e.message}');
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('General error in deleteUser: $e');
      throw Exception('Foydalanuvchi o\'chirishda kutilmagan xatolik: $e');
    }
  }

  // Assign filial to user - PUT /api/users/{id}/assign-filial
  Future<User> assignFilialToUser(int userId, int filialId) async {
    try {
      print('Assigning filial $filialId to user $userId'); // Debug log

      final response = await dio.put(
        '${AppUrls.users}/$userId/assign-filial',
        data: AssignFilialRequest(filialId: filialId).toJson(),
      );

      print(
          'Assign filial response status: ${response.statusCode}'); // Debug log
      print('Assign filial response data: ${response.data}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          final user = await getUserById(userId);
          if (user != null) {
            return user;
          } else {
            throw Exception(
                'Yangilangan foydalanuvchi ma\'lumotlarini olishda xatolik');
          }
        } else {
          final errorMessage =
              responseData['message'] ?? 'Filial belgilashda xatolik';
          print('Assign filial error message: $errorMessage');
          throw Exception(errorMessage);
        }
      } else {
        final responseData = response.data;
        final errorMessage =
            responseData['message'] ?? 'Server xatosi: ${response.statusCode}';
        print('Assign filial status error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      print('DioException in assignFilialToUser: ${e.toString()}'); // Debug log

      if (e.response != null) {
        print(
            'Assign filial error response data: ${e.response!.data}'); // Debug log

        if (e.response!.statusCode == 404) {
          throw Exception('Foydalanuvchi yoki filial topilmadi');
        }

        dynamic responseData = e.response!.data;
        String errorMessage;

        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              'Server xatosi: ${e.response!.statusCode}';
        } else {
          errorMessage = 'Server xatosi: ${e.response!.statusCode}';
        }

        print('Parsed assign filial error message: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('Assign filial network error: ${e.message}');
        throw Exception('Tarmoq xatosi: ${e.message}');
      }
    } catch (e) {
      print('General error in assignFilialToUser: $e');
      throw Exception('Filial belgilashda kutilmagan xatolik: $e');
    }
  }

  // Helper methods
  Future<List<User>> getUsersByFilial(int filialId) async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => user.filialId == filialId).toList();
    } catch (e) {
      throw Exception(
          'Filial bo\'yicha foydalanuvchilarni olishda xatolik: $e');
    }
  }

  Future<List<User>> getAdminUsers() async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => user.isAdmin).toList();
    } catch (e) {
      throw Exception('Admin foydalanuvchilarni olishda xatolik: $e');
    }
  }

  Future<List<User>> getRegularUsers() async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => !user.isAdmin).toList();
    } catch (e) {
      throw Exception('Oddiy foydalanuvchilarni olishda xatolik: $e');
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
      throw Exception('Foydalanuvchilarni qidirishda xatolik: $e');
    }
  }

  Future<User> toggleAdminStatus(int userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        throw Exception('Foydalanuvchi topilmadi');
      }

      final updateRequest = UpdateUserRequest(isAdmin: !user.isAdmin);
      return await updateUser(userId, updateRequest);
    } catch (e) {
      throw Exception('Admin holatini o\'zgartirishda xatolik: $e');
    }
  }
}
