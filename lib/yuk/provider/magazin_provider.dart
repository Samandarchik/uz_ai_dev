import 'package:flutter/material.dart';
import 'package:uz_ai_dev/yuk/models/magazin_model.dart';
import 'package:uz_ai_dev/yuk/services/magazin_service.dart';

// "Qarz daftari" holat boshqaruvchisi: magazinlar ro'yxati + umumiy qarz,
// tanlangan magazinning qarz yozuvlari. Mutatsiyalardan keyin ro'yxat
// XOTIRADA yangilanadi (to'liq refetch yo'q — ma'lumot kichik va lokal
// hisob aniq: umumiy qarz = magazinlar total_debt yig'indisi).
// Mutatsiya metodlari xatoda Exception otadi — UI ushlab SnackBar ko'rsatadi.
class MagazinProvider extends ChangeNotifier {
  final MagazinService _service = MagazinService();

  // Ro'yxat ekrani holati.
  List<Magazin> magazins = [];
  double totalDebt = 0;
  bool isLoading = false;
  String? errorMessage;

  // Tafsilot ekrani holati (hozir ochiq magazin).
  Magazin? detailMagazin;
  List<MagazinDebt> debts = [];
  bool isLoadingDetail = false;
  String? detailError;

  // GET ro'yxat + umumiy qarz.
  Future<void> fetchMagazins() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _service.fetchMagazins();
      magazins = res.magazins;
      totalDebt = res.totalDebt;
    } catch (e) {
      errorMessage = '$e'.replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Tanlangan magazinning qarz yozuvlarini yuklash. Avval ro'yxatdan kelgan
  // magazin ko'rsatilib turadi, server javobi kelgach total_debt ham
  // ro'yxatdagi nusxaga sinxronlanadi.
  Future<void> fetchDetail(Magazin magazin) async {
    detailMagazin = magazin;
    debts = [];
    detailError = null;
    isLoadingDetail = true;
    notifyListeners();
    try {
      final res = await _service.fetchDebts(magazin.id);
      detailMagazin = res.magazin ?? magazin;
      debts = res.debts;
      _syncListEntry(detailMagazin!);
    } catch (e) {
      detailError = '$e'.replaceFirst('Exception: ', '');
    } finally {
      isLoadingDetail = false;
      notifyListeners();
    }
  }

  // Yangi magazin: POST, javobdagi magazin ro'yxat boshiga qo'shiladi
  // (yangi magazinning qarzi 0 — umumiy qarz o'zgarmaydi).
  Future<void> createMagazin({
    required String name,
    required String shopName,
    required String phone,
    required String imageUrl,
  }) async {
    final created = await _service.createMagazin(
      name: name,
      shopName: shopName,
      phone: phone,
      imageUrl: imageUrl,
    );
    magazins.insert(0, created);
    _recomputeTotal();
    notifyListeners();
  }

  // Magazinni tahrirlash: PUT. total_debt tahrirda o'zgarmaydi, shuning
  // uchun mavjud qiymat saqlab qolinadi (server javobida bo'lmasa ham).
  Future<void> updateMagazin(
    int id, {
    required String name,
    required String shopName,
    required String phone,
    required String imageUrl,
  }) async {
    final updated = await _service.updateMagazin(
      id,
      name: name,
      shopName: shopName,
      phone: phone,
      imageUrl: imageUrl,
    );
    final idx = magazins.indexWhere((m) => m.id == id);
    final keepDebt = idx >= 0
        ? magazins[idx].totalDebt
        : (detailMagazin?.id == id ? detailMagazin!.totalDebt : 0.0);
    final merged = updated.copyWith(totalDebt: keepDebt);
    if (idx >= 0) magazins[idx] = merged;
    if (detailMagazin?.id == id) detailMagazin = merged;
    notifyListeners();
  }

  // Magazinni (va backendda uning barcha qarz yozuvlarini) o'chirish.
  Future<void> deleteMagazin(int id) async {
    await _service.deleteMagazin(id);
    magazins.removeWhere((m) => m.id == id);
    if (detailMagazin?.id == id) {
      detailMagazin = null;
      debts = [];
    }
    _recomputeTotal();
    notifyListeners();
  }

  // Qarz yozuvi qo'shish: POST, yozuv ro'yxat boshiga (eng yangi birinchi),
  // magazin va umumiy jami xotirada qayta hisoblanadi.
  Future<void> addDebt(int magazinId, double amount, String comment) async {
    final debt = await _service.addDebt(magazinId, amount, comment);
    if (detailMagazin?.id == magazinId) {
      debts.insert(0, debt);
      detailMagazin =
          detailMagazin!.copyWith(totalDebt: detailMagazin!.totalDebt + amount);
      _syncListEntry(detailMagazin!);
    } else {
      _shiftListEntryDebt(magazinId, amount);
    }
    notifyListeners();
  }

  // Xato kiritilgan qarz yozuvini o'chirish.
  Future<void> deleteDebt(int magazinId, MagazinDebt debt) async {
    await _service.deleteDebt(magazinId, debt.id);
    if (detailMagazin?.id == magazinId) {
      debts.removeWhere((d) => d.id == debt.id);
      detailMagazin = detailMagazin!
          .copyWith(totalDebt: detailMagazin!.totalDebt - debt.amount);
      _syncListEntry(detailMagazin!);
    } else {
      _shiftListEntryDebt(magazinId, -debt.amount);
    }
    notifyListeners();
  }

  // Magazin rasmi: mavjud /api/yuk/upload endpointiga yuklab, relativ
  // '/static/yuk/...' URL qaytaradi (keyin image_url sifatida yuboriladi).
  Future<String> uploadImage(String path) => _service.uploadImage(path);

  // Ro'yxatdagi nusxani tafsilotdagi (yangi total_debt'li) magazin bilan
  // almashtirish va umumiy jami'ni qayta hisoblash.
  void _syncListEntry(Magazin m) {
    final idx = magazins.indexWhere((e) => e.id == m.id);
    if (idx >= 0) magazins[idx] = m;
    _recomputeTotal();
  }

  // Tafsilot ochiq bo'lmagan magazin qarzini delta bilan surish.
  void _shiftListEntryDebt(int magazinId, double delta) {
    final idx = magazins.indexWhere((e) => e.id == magazinId);
    if (idx >= 0) {
      magazins[idx] =
          magazins[idx].copyWith(totalDebt: magazins[idx].totalDebt + delta);
    }
    _recomputeTotal();
  }

  // Umumiy qarz = barcha magazinlar total_debt yig'indisi.
  void _recomputeTotal() {
    totalDebt = magazins.fold(0.0, (sum, m) => sum + m.totalDebt);
  }
}
