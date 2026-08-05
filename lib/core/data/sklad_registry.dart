// core/data/sklad_registry.dart — sklad nomlarining YAGONA manbai
// (SkladRegistry). Ilgari nomlar 6 xil faylda hardcode `Map<int,String>` edi;
// endi superadmin ularni serverda tahrirlaydi (`/api/sklads`), ilova esa shu
// registrdan o'qiydi.
//
// Ishlash tartibi:
//   main()      → SkladRegistry.load()     — SharedPreferences keshidan (oflayn ham ishlaydi)
//   splash/login → SkladRegistry.refresh() — serverdan yangilab, keshga yozadi
//   ekranlar    → SkladRegistry.nameOf(id) / .names / .ids
//
// Kesh yo'q bo'lsa eski hardcode 4 ta nom ishlatiladi (backend ham xuddi shu
// id → nom bilan urug'lanadi), shuning uchun birinchi ochilishda ham nom bor.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/models/sklad_model.dart';

class SkladRegistry {
  SkladRegistry._();

  static const String _prefsKey = 'sklads_cache';

  // Server ham, kesh ham bo'lmaganda ishlatiladigan eski hardcode ro'yxat.
  static const Map<int, String> _fallback = {
    1: 'Marxabo Sklat',
    2: 'Sardor Sklat',
    3: 'Fresco Sklat',
    4: 'Personal Sklad',
  };

  static Map<int, String> _names = Map<int, String>.from(_fallback);

  /// id → nom (server tartibida). Faqat O'QISH uchun.
  static Map<int, String> get names => Map<int, String>.unmodifiable(_names);

  /// Skladlar id'lari (server tartibida) — tab/dropdown quriladigan joylar uchun.
  static List<int> get ids => _names.keys.toList();

  /// Sklad nomi; noma'lum id uchun «Sklad N» (eski xatti-harakat bilan bir xil).
  static String nameOf(int id) => _names[id] ?? 'Sklad $id';

  /// Yozuvda saqlangan `sklad_name` SNAPSHOT'i bor joylar uchun ko'rsatish nomi.
  /// Sklad hali mavjud bo'lsa uning JORIY nomi ustun — superadmin qayta
  /// nomlagan bo'lsa eski buyurtmalar ham yangi nom bilan ko'rinadi. Sklad
  /// o'chirilgan bo'lsa yozuvdagi eski nom ishlatiladi (tarix yo'qolmaydi).
  static String display(int id, String snapshot) =>
      _names[id] ?? (snapshot.isNotEmpty ? snapshot : 'Sklad $id');

  /// Keshdan yuklash — tarmoqsiz, main() da await qilinadi.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _apply(decoded
            .whereType<Map>()
            .map((e) => Sklad.fromJson(Map<String, dynamic>.from(e)))
            .toList());
      }
    } catch (e) {
      debugPrint('SkladRegistry.load: $e');
    }
  }

  /// Serverdan yangilash. Xato bo'lsa (tarmoq yo'q, token yo'q) eski nomlar
  /// qoladi — ekran hech qachon bo'sh nom ko'rsatmaydi.
  static Future<List<Sklad>> refresh() async {
    final list = await fetch();
    _apply(list);
    await _cache(list);
    return list;
  }

  /// Xatoni yutadigan variant — splash/login kabi «bo'lsa yaxshi» joylar uchun.
  static Future<void> refreshSilently() async {
    try {
      await refresh();
    } catch (e) {
      debugPrint('SkladRegistry.refresh: $e');
    }
  }

  /// GET /api/sklads → [{id, name}]. Registrni O'ZGARTIRMAYDI.
  static Future<List<Sklad>> fetch() async {
    final response = await sl<Dio>().get(AppUrls.sklads);
    final data = response.data is Map ? response.data['data'] : response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Sklad.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// CRUD dan keyin (sklads_ui) registrni yangi ro'yxat bilan almashtirish.
  static Future<void> update(List<Sklad> list) async {
    _apply(list);
    await _cache(list);
  }

  static void _apply(List<Sklad> list) {
    if (list.isEmpty) return;
    _names = {for (final s in list) s.id: s.name};
  }

  static Future<void> _cache(List<Sklad> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('SkladRegistry.cache: $e');
    }
  }
}
