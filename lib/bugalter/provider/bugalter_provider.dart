// bugalter/provider/bugalter_provider.dart — Bugalter (hisobchi) provideri: BugalterProvider
// (ChangeNotifier). Holat: orders (barcha sklad narxlangan buyurtmalari), yukUsers; editItemQty
// (miqdor + summa tuzatish), deleteItem (mahsulotni soft-delete o'chirish), yuk keltiruvchiga
// to'lov (submitPayment) va forSklad filtri.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/bugalter/models/yuk_user_model.dart';
import 'package:uz_ai_dev/core/clearable_provider.dart';
import 'package:uz_ai_dev/core/utils/order_sequence.dart';
import 'package:uz_ai_dev/bugalter/services/bugalter_service.dart';
import 'package:uz_ai_dev/core/widgets/order_period.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';

// Bugalter bosh ekrani uchun holat boshqaruvchi: barcha skladlarning
// narxlangan/qabul qilingan buyurtmalari (mahsulotlar + xarajatlar bilan).
class BugalterProvider extends ChangeNotifier with ClearableProvider {
  final BugalterService _service = BugalterService();

  List<YukOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

  // Yopiq buyurtmalar tarixi oynasi (30/90 kun yoki hammasi).
  // Saqlanmaydi — ilova qayta ochilganda default 30 kunga qaytadi.
  OrderPeriod ordersPeriod = OrderPeriod.last30;

  Future<void> fetchOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      orders = await _service.fetchOrders(
        days: ordersPeriod.days,
        all: ordersPeriod.isAll,
      );
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Davr almashtirilganda ro'yxat serverdan qayta yuklanadi.
  Future<void> setOrdersPeriod(OrderPeriod period) async {
    if (period == ordersPeriod) return;
    ordersPeriod = period;
    await fetchOrders();
  }

  // Buyurtma ichidagi mahsulot miqdorini (gram xatolari) va/yoki SUMMASINI
  // tuzatish. Kamida bittasi berilishi kerak; subtotal — BUTUN so'm.
  // Server to'liq yangilangan buyurtmani qaytaradi — ro'yxatdagi mos
  // buyurtma (order.id bo'yicha) almashtiriladi, Consumer'lar qayta quriladi.
  // Xato bo'lsa Exception qayta otiladi (UI snackbar ko'rsatadi).
  Future<void> editItemQty({
    required int orderId,
    required int productId,
    num? taken,
    num? received,
    int? subtotal,
  }) async {
    final updated = await _service.editItemQty(
      orderId: orderId,
      productId: productId,
      taken: taken,
      received: received,
      subtotal: subtotal,
    );
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      orders[index] = updated;
    }
    notifyListeners();
  }

  // Buyurtma ichidagi mahsulotni o'chirish (soft-delete: serverda item
  // deleted=true, miqdor/summa nolga qaytadi, jami summalar qayta hisoblanadi).
  // Server to'liq yangilangan buyurtmani qaytaradi — ro'yxatdagi mos
  // buyurtma (order.id bo'yicha) almashtiriladi, Consumer'lar qayta quriladi.
  // Xato bo'lsa Exception qayta otiladi (UI snackbar ko'rsatadi).
  Future<void> deleteItem({
    required int orderId,
    required int productId,
  }) async {
    final updated = await _service.deleteItem(
      orderId: orderId,
      productId: productId,
    );
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      orders[index] = updated;
    }
    notifyListeners();
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

  // Logout: buyurtmalar, yuk keltiruvchilar va holat maydonlarini tozalaymiz.
  @override
  void clear() {
    orders = [];
    isLoading = false;
    errorMessage = null;
    ordersPeriod = OrderPeriod.last30;
    yukUsers = [];
    isLoadingYukUsers = false;
    yukUsersError = null;
    isSubmittingPayment = false;
    notifyListeners();
  }

  // Berilgan sklad buyurtmalari (null -> hammasi). Tartib — ombor va yuk
  // ekranlaridagi bilan BIR XIL yagona ketma-ketlik (created ASC, keyin id;
  // core/utils/order_sequence.dart). Kunlik kartalarda yangi KUN baribir
  // tepada qoladi (groupYukOrdersByDay), tartib kun ICHIDA qo'llanadi.
  List<YukOrder> forSklad(int? skladId) {
    return sortedOrderSeq(
      skladId == null ? orders : orders.where((o) => o.skladId == skladId),
      createdOf: (o) => o.created,
      idOf: (o) => o.id,
    );
  }
}
