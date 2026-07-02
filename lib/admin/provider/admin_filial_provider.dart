// ==================== FILIAL PROVIDER ====================
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/services/api_filial_service.dart';
import 'package:uz_ai_dev/admin/model/user_model.dart';

class FilialProviderAdmin extends ChangeNotifier {
  final ApiFilialService _service = ApiFilialService();

  List<Filial> _filials = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Filial> get filials => _filials;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
}
