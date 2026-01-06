import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin_agent/model/user_model.dart';
import 'package:uz_ai_dev/admin_agent/services/user_management_service.dart';

class UserProviderAdminAgent extends ChangeNotifier {
  final UserManagementService _service = UserManagementService();

  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  String? _error;
  User? _selectedUser;

  // Filter options
  bool? _filterIsAdmin;
  int? _filterFilialId;
  String _searchQuery = '';

  // Getters
  List<User> get users => _users;
  List<User> get filteredUsers => _filteredUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get selectedUser => _selectedUser;
  bool? get filterIsAdmin => _filterIsAdmin;
  int? get filterFilialId => _filterFilialId;
  String get searchQuery => _searchQuery;

  // Get all users
  Future<void> getAllUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _service.getAllUsers();
      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user by ID
  Future<User?> getUserById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _service.getUserById(id);
      _selectedUser = user;
      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Create new user
  Future<bool> createUser(CreateUserRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newUser = await _service.createUser(request);
      _users.add(newUser);
      _applyFilters();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update user
  Future<bool> updateUser(int id, UpdateUserRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await _service.updateUser(id, request);

      final index = _users.indexWhere((u) => u.id == id);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      _applyFilters();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete user
  Future<bool> deleteUser(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _service.deleteUser(id);
      if (success) {
        _users.removeWhere((u) => u.id == id);
        _applyFilters();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Assign filial to user
  Future<bool> assignFilialToUser(int userId, int filialId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await _service.assignFilialToUser(userId, filialId);

      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      _applyFilters();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get users by filial
  Future<void> getUsersByFilial(int filialId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _filteredUsers = await _service.getUsersByFilial(filialId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get admin users
  Future<void> getAdminUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _filteredUsers = await _service.getAdminUsers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get regular users
  Future<void> getRegularUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _filteredUsers = await _service.getRegularUsers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search users
  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _filteredUsers = await _service.searchUsers(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search users locally (without API call)
  void searchUsersLocally(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Toggle admin status
  Future<bool> toggleAdminStatus(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await _service.toggleAdminStatus(userId);

      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      _applyFilters();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Filter by admin status
  void filterByAdminStatus(bool? isAdmin) {
    _filterIsAdmin = isAdmin;
    _applyFilters();
  }

  // Filter by filial
  void filterByFilial(int? filialId) {
    _filterFilialId = filialId;
    _applyFilters();
  }

  // Apply all filters locally
  void _applyFilters() {
    _filteredUsers = _users;

    // Apply admin filter
    if (_filterIsAdmin != null) {
      _filteredUsers = _filteredUsers
          .where((user) => user.isAdmin == _filterIsAdmin)
          .toList();
    }

    // Apply filial filter
    if (_filterFilialId != null) {
      _filteredUsers = _filteredUsers
          .where((user) => user.filialId == _filterFilialId)
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      _filteredUsers = _filteredUsers.where((user) {
        final nameMatch = user.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        final phoneMatch = user.phone.contains(_searchQuery);
        return nameMatch || phoneMatch;
      }).toList();
    }

    notifyListeners();
  }

  // Clear all filters
  void clearFilters() {
    _filterIsAdmin = null;
    _filterFilialId = null;
    _searchQuery = '';
    _filteredUsers = _users;
    notifyListeners();
  }

  // Set selected user
  void setSelectedUser(User? user) {
    _selectedUser = user;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _users = [];
    _filteredUsers = [];
    _selectedUser = null;
    _filterIsAdmin = null;
    _filterFilialId = null;
    _searchQuery = '';
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Get statistics
  int get totalUsers => _users.length;
  int get adminCount => _users.where((u) => u.isAdmin).length;
  int get regularUserCount => _users.where((u) => !u.isAdmin).length;
  int get usersWithFilialCount =>
      _users.where((u) => u.filialId != null).length;
  int get usersWithoutFilialCount =>
      _users.where((u) => u.filialId == null).length;
}
