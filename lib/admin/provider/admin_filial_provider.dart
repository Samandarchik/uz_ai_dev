// admin/provider/admin_filial_provider.dart — filiallar holati
// (FilialProviderAdmin, ChangeNotifier): ApiFilialService orqali filiallar
// ro'yxatini oladi (getFilials), isLoading/error holatini ushlaydi.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/services/api_filial_service.dart';
import 'package:uz_ai_dev/admin/model/user_model.dart';
import 'package:uz_ai_dev/core/clearable_provider.dart';

class FilialProviderAdmin extends ChangeNotifier with ClearableProvider {
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

  // Logout: filiallar va yuklanish/xato holatini tozalaymiz.
  @override
  void clear() {
    _filials = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
