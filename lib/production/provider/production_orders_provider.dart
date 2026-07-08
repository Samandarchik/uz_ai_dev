import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/network/order_socket.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';

// Ishlab chiqarish buyurtmalari ro'yxati uchun umumiy holat boshqaruvchi.
// Server rolga qarab filtrlaydi (ombor — o'z skladlari, admin/bugalter —
// hammasi), shuning uchun uch rol ham bitta bazadan meros oladi; har rol
// o'z amallarini qo'shadi (issue / delete / status).
abstract class BaseProductionOrdersProvider extends ChangeNotifier {
  final ProductionService service = ProductionService();

  List<ProductionOrder> orders = [];
  bool isLoading = false;
  String? errorMessage;

  bool _disposed = false;

  ProductionOrder? orderById(int id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> fetchOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      orders = await service.fetchOrders();
      _sortOrders();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Spinner'siz jim yangilash (socket hodisalari uchun).
  Future<void> refreshSilently() async {
    try {
      orders = await service.fetchOrders();
      _sortOrders();
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Jim qolamiz — foydalanuvchi pull-to-refresh bilan qayta oladi.
    }
  }

  // Bitta buyurtmani serverdan qayta olib lokal ro'yxatga qo'llash
  // (tafsilot sahifasi ochilganda / pull-to-refresh).
  Future<void> refreshOrder(int id) async {
    try {
      final updated = await service.fetchOrder(id);
      if (updated != null) upsert(updated);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Jim — tafsilot ekrani eski holatda qolaveradi.
    }
  }

  void upsert(ProductionOrder order) {
    final i = orders.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      orders[i] = order;
    } else {
      orders.insert(0, order);
      _sortOrders();
    }
  }

  void _sortOrders() {
    orders.sort((a, b) {
      final da = DateTime.tryParse(a.created) ?? DateTime(2000);
      final db = DateTime.tryParse(b.created) ?? DateTime(2000);
      return db.compareTo(da); // yangisi tepada
    });
  }

  // ─────────────────────── Real-time (WebSocket) ───────────────────────
  StreamSubscription<ProductionSocketEvent>? _socketSub;

  // production hodisasida ro'yxatni jim yangilaymiz (payload'siz signal).
  void connectSocket() {
    _socketSub ??=
        OrderSocket.instance.productionEvents.listen((_) => refreshSilently());
    OrderSocket.instance.connect();
  }

  void disconnectSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    OrderSocket.instance.disconnect();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnectSocket();
    super.dispose();
  }
}

// Ombor: o'z skladiga kelgan ishlab chiqarish buyurtmalari + «Berdim».
class OmborProductionProvider extends BaseProductionOrdersProvider {
  // Hozir amal bajarilayotgan bo'lim kaliti: "orderId:pi:si" (tugma spinner'i).
  String? busyStageKey;

  static String stageKey(int orderId, int pi, int si) => '$orderId:$pi:$si';

  // «Berdim» — chiqim + material_status=berildi. Xato xabari qaytadi
  // (null — muvaffaqiyat); UI snackbar ko'rsatadi.
  Future<String?> issueStage(int orderId, int pi, int si) async {
    busyStageKey = stageKey(orderId, pi, si);
    notifyListeners();
    try {
      final updated = await service.issueStage(orderId, pi, si);
      if (updated != null) {
        upsert(updated);
      } else {
        final fresh = await service.fetchOrder(orderId);
        if (fresh != null) upsert(fresh);
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      busyStageKey = null;
      if (!_disposed) notifyListeners();
    }
  }
}

// Admin: barcha buyurtmalar, faqat ko'rish (read-only).
class AdminProductionProvider extends BaseProductionOrdersProvider {}

// Bugalter: barcha buyurtmalar + o'chirish + statusni qo'lda almashtirish
// (bu ikkala amal FAQAT bugalterda).
class BugalterProductionProvider extends BaseProductionOrdersProvider {
  // Hozir amal bajarilayotgan buyurtma (tugmalarda spinner uchun).
  int? busyOrderId;

  // DELETE /api/production/orders/{id}. Xato xabari qaytadi (null — OK).
  Future<String?> deleteOrder(int id) async {
    busyOrderId = id;
    notifyListeners();
    try {
      await service.deleteOrder(id);
      orders.removeWhere((o) => o.id == id);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      busyOrderId = null;
      if (!_disposed) notifyListeners();
    }
  }

  // PUT /api/production/orders/{id}/status. Xato xabari qaytadi (null — OK).
  Future<String?> setStatus(int id, String status) async {
    busyOrderId = id;
    notifyListeners();
    try {
      final updated = await service.updateStatus(id, status);
      if (updated != null) {
        upsert(updated);
      } else {
        await refreshOrder(id);
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      busyOrderId = null;
      if (!_disposed) notifyListeners();
    }
  }
}
