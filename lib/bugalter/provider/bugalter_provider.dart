import 'package:flutter/material.dart';
import 'package:uz_ai_dev/bugalter/models/yuk_user_model.dart';
import 'package:uz_ai_dev/bugalter/services/bugalter_service.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';

// Bugalter bosh ekrani uchun holat boshqaruvchi: barcha skladlarning
// narxlangan/qabul qilingan buyurtmalari (mahsulotlar + xarajatlar bilan).
class BugalterProvider extends ChangeNotifier {
  final BugalterService _service = BugalterService();

  List<YukOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      orders = await _service.fetchOrders();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────── Pul berish (yuk keltiruvchiga to'lov) ───────────────

  // Dropdown uchun yuk keltiruvchi foydalanuvchilar ro'yxati.
  List<YukUser> yukUsers = [];
  bool isLoadingYukUsers = false;
  String? yukUsersError;

  // Hozir to'lov yuborilmoqdami (tugma spinner'i uchun).
  bool isSubmittingPayment = false;

  // Dropdown uchun yuk keltiruvchilar ro'yxatini olish.
  Future<void> fetchYukUsers() async {
    isLoadingYukUsers = true;
    yukUsersError = null;
    notifyListeners();

    try {
      yukUsers = await _service.fetchYukUsers();
    } catch (e) {
      yukUsersError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingYukUsers = false;
      notifyListeners();
    }
  }

  // Yuk keltiruvchiga pul berish. Muvaffaqiyatда backend message qaytadi,
  // xatoда Exception otiladi (UI snackbar ko'rsatadi).
  Future<String> submitPayment({
    required int userId,
    required int amount,
    String comment = '',
  }) async {
    isSubmittingPayment = true;
    notifyListeners();
    try {
      return await _service.createPayment(
        userId: userId,
        amount: amount,
        comment: comment,
      );
    } finally {
      isSubmittingPayment = false;
      notifyListeners();
    }
  }

  // Berilgan sklad buyurtmalari (null -> hammasi), yangisi tepada.
  List<YukOrder> forSklad(int? skladId) {
    final list = skladId == null
        ? List.of(orders)
        : orders.where((o) => o.skladId == skladId).toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a.created) ?? DateTime(2000);
      final db = DateTime.tryParse(b.created) ?? DateTime(2000);
      return db.compareTo(da);
    });
    return list;
  }
}
