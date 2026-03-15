import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/bringer/models/bringer_models.dart';
import 'package:uz_ai_dev/bringer/services/bringer_service.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

// Bringer ko'radigan mahsulot modeli
class BringerProductModel {
  final int id;
  final String name;
  final String? type;
  final num? grams;
  final String category;
  final String? imageUrl;
  final int? bringerId;

  BringerProductModel({
    required this.id,
    required this.name,
    this.type,
    this.grams,
    required this.category,
    this.imageUrl,
    this.bringerId,
  });

  factory BringerProductModel.fromJson(Map<String, dynamic> json, String category) {
    return BringerProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['type'],
      grams: json['grams'],
      category: category,
      imageUrl: json['image_url'],
      bringerId: json['bringer_id'],
    );
  }
}

class BringerProvider extends ChangeNotifier {
  final BringerService _service = BringerService();
  final Dio _dio = sl<Dio>();

  // Bringer Profiles
  List<BringerProfile> _profiles = [];
  List<BringerProfile> get profiles => _profiles;

  // Active order
  BringerOrder? _activeOrder;
  BringerOrder? get activeOrder => _activeOrder;

  // Orders history
  List<BringerOrder> _orders = [];
  List<BringerOrder> get orders => _orders;

  // Tasks
  List<BringerTaskItem> _tasks = [];
  List<BringerTaskItem> get tasks => _tasks;

  // Balance
  BringerBalance? _balance;
  BringerBalance? get balance => _balance;

  // Transactions
  List<BringerTransaction> _transactions = [];
  List<BringerTransaction> get transactions => _transactions;

  // Mahsulotlar (bringer_id bo'yicha filtrlangan)
  Map<String, List<BringerProductModel>> _productsByCategory = {};
  Map<String, List<BringerProductModel>> get productsByCategory =>
      _productsByCategory;

  // State
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  int? _selectedBringerProfileId;
  int? get selectedBringerProfileId => _selectedBringerProfileId;

  void setSelectedBringerProfile(int id) {
    _selectedBringerProfileId = id;
    notifyListeners();
  }

  // ==================== MAHSULOTLAR (filtrlangan) ====================

  /// Mahsulotlarni yuklash va bringer_id bo'yicha filtrlash:
  /// - bringer_id == null → barcha bringerlarga ko'rinadi
  /// - bringer_id == myId → faqat menga ko'rinadi
  /// - bringer_id == boshqa → ko'rinmaydi
  Future<void> loadProducts(int bringerProfileId) async {
    try {
      final response = await _dio.get(AppUrls.product1);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data['data'] ?? {};

        _productsByCategory = {};
        data.forEach((category, products) {
          if (products is List) {
            final filtered = products.where((item) {
              final bid = item['bringer_id'];
              // bringer_id yo'q → hammaga ko'rinadi
              // bringer_id == meniki → menga ko'rinadi
              return bid == null || bid == bringerProfileId;
            }).map((item) => BringerProductModel.fromJson(item, category))
                .toList();

            if (filtered.isNotEmpty) {
              _productsByCategory[category] = filtered;
            }
          }
        });
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<BringerProductModel> get allProducts {
    return _productsByCategory.values.expand((list) => list).toList();
  }

  // ==================== PROFILES ====================

  Future<void> loadProfiles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profiles = await _service.getAllProfiles();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProfile(BringerProfile profile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _service.createProfile(profile);
      _profiles.add(created);
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

  Future<bool> updateProfile(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateProfile(id, data);
      final index = _profiles.indexWhere((p) => p.id == id);
      if (index != -1) _profiles[index] = updated;
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

  Future<bool> deleteProfile(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final success = await _service.deleteProfile(id);
      if (success) _profiles.removeWhere((p) => p.id == id);
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

  // ==================== ORDERS ====================
  // Backend tokendan avtomatik bringer_profile_id ni oladi

  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _service.getOrders();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadActiveOrder() async {
    try {
      _activeOrder = await _service.getActiveOrder();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> createOrder() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _activeOrder = await _service.createOrder();
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

  Future<bool> addOrderItem({
    required int productId,
    required double count,
    required int price,
    String? videoUrl,
    String? comment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _activeOrder = await _service.addOrderItem(
        productId: productId,
        count: count,
        price: price,
        videoUrl: videoUrl,
        comment: comment,
      );
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

  Future<bool> pushOrder({String? comment}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final pushed = await _service.pushOrder(comment: comment);
      _activeOrder = null;
      _orders.insert(0, pushed);
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

  Future<bool> deliverOrder(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final delivered = await _service.deliverOrder(orderId);
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) _orders[index] = delivered;
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

  // ==================== TASKS ====================

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = await _service.getTasks();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ==================== BALANCE ====================

  Future<void> loadBalance() async {
    try {
      _balance = await _service.getBalance();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addBalance({
    required int bringerProfileId,
    required int amount,
    String? comment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _balance = await _service.addBalance(
        bringerProfileId: bringerProfileId,
        amount: amount,
        comment: comment,
      );
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

  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _transactions = await _service.getTransactions();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
