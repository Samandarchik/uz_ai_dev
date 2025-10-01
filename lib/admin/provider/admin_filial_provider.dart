// ==================== FILIAL PROVIDER ====================
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/services/api_filial_service.dart';
import 'package:uz_ai_dev/user/models/user_model.dart';

class FilialProviderAdmin extends ChangeNotifier {
  final ApiFilialService _service = ApiFilialService();

  List<Filial> _filials = [];
  bool _isLoading = false;
  String? _error;
  Filial? _selectedFilial;

  // Getters
  List<Filial> get filials => _filials;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Filial? get selectedFilial => _selectedFilial;

  // Get all filials
  Future<void> getFilials() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _filials = await _service.getFilials();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get filial by ID
  Future<Filial?> getFilialById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final filial = await _service.getFilialById(id);
      _selectedFilial = filial;
      _isLoading = false;
      notifyListeners();
      return filial;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Set selected filial
  void setSelectedFilial(Filial? filial) {
    _selectedFilial = filial;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _filials = [];
    _selectedFilial = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
