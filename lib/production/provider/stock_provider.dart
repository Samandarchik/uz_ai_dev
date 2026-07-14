import 'package:flutter/material.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/services/stock_service.dart';

// Sklad qoldig'i holati: sklad bo'yicha qoldiqlar keshi, korreksiya va
// harakatlar tarixi. Ombor (o'z skladi) va admin (hamma sklad) sahifalari
// bitta shu provider'ni ishlatadi.
class StockProvider extends ChangeNotifier {
  final StockService _service = StockService();

  final Map<int, List<StockRow>> _bySklad = {};
  final Set<int> _loading = {};
  final Map<int, String> _errors = {};

  bool isSubmitting = false; // korreksiya yuborilayotganda

  bool _disposed = false;

  // null — hali yuklanmagan; bo'sh ro'yxat — yuklangan lekin qoldiq yo'q.
  List<StockRow>? stockFor(int skladId) => _bySklad[skladId];

  bool isLoading(int skladId) => _loading.contains(skladId);

  String? errorFor(int skladId) => _errors[skladId];

  // Mahsulot qoldig'i: yozuv bo'lmasa null (0 dan farqli — «yozuv yo'q»).
  double? qtyFor(int skladId, int productId) {
    final rows = _bySklad[skladId];
    if (rows == null) return null;
    for (final r in rows) {
      if (r.productId == productId) return r.qty;
    }
    return null;
  }

  // Mahsulot birligi (type): avval sklad qoldiq qatorlaridan, bo'lmasa
  // katalogdan. Topilmasa null (formatlashda faktor 1 ishlaydi).
  String? typeFor(int skladId, int productId) {
    final rows = _bySklad[skladId];
    if (rows != null) {
      for (final r in rows) {
        if (r.productId == productId && r.type.isNotEmpty) return r.type;
      }
    }
    for (final c in catalog) {
      if (c.id == productId && c.type.isNotEmpty) return c.type;
    }
    return null;
  }

  Future<void> fetchStock(int skladId) async {
    _loading.add(skladId);
    _errors.remove(skladId);
    notifyListeners();

    try {
      _bySklad[skladId] = await _service.fetchStock(skladId);
    } catch (e) {
      _errors[skladId] = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading.remove(skladId);
      if (!_disposed) notifyListeners();
    }
  }

  // Spinner'siz jim yangilash («Berdim» dan keyin qoldiqni yangilash).
  Future<void> refreshSilently(int skladId) async {
    try {
      _bySklad[skladId] = await _service.fetchStock(skladId);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Jim — foydalanuvchi pull-to-refresh bilan qayta oladi.
    }
  }

  // Korreksiya (+/- qty). Muvaffaqiyatda skladni jim yangilaydi va null
  // qaytaradi; xatoda xabar matni qaytadi (UI snackbar ko'rsatadi).
  Future<String?> adjust({
    required int skladId,
    required int productId,
    required double qty,
    required String comment,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _service.adjust(
        skladId: skladId,
        productId: productId,
        qty: qty,
        comment: comment,
      );
      await refreshSilently(skladId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Min chegara o'rnatish. Muvaffaqiyatda skladni jim yangilaydi va null
  // qaytaradi; xatoda xabar matni qaytadi (UI snackbar ko'rsatadi).
  Future<String?> setMin({
    required int skladId,
    required int productId,
    required double minQty,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _service.setMin(
        skladId: skladId,
        productId: productId,
        minQty: minQty,
      );
      await refreshSilently(skladId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Inventarizatsiya yuborish. Muvaffaqiyatda (changed, null) qaytadi va
  // sklad jim yangilanadi; xatoda (null, xabar).
  Future<(int?, String?)> submitInventory({
    required int skladId,
    required List<Map<String, dynamic>> items,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      final changed = await _service.inventory(skladId: skladId, items: items);
      await refreshSilently(skladId);
      return (changed, null);
    } catch (e) {
      return (null, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Harakatlar tarixi — keshlamasdan to'g'ridan-to'g'ri (bottom sheet o'zi
  // FutureBuilder bilan boshqaradi).
  Future<List<StockMove>> fetchMoves(
    int skladId, {
    int? productId,
    int? limit,
  }) =>
      _service.fetchMoves(skladId, productId: productId, limit: limit);

  // ───────────── Korreksiya dialogi uchun katalog (bir marta) ─────────────
  List<CatalogProduct> catalog = [];
  bool _catalogLoaded = false;

  Future<void> ensureCatalog() async {
    if (_catalogLoaded) return;
    catalog = await _service.fetchCatalog();
    _catalogLoaded = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
