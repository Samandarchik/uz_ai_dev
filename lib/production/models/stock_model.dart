// Sklad qoldig'i (inventar) modellari — ombor/admin qoldiq sahifalari.
// Backend JSON snake_case; kontrakt: mone_app/reja.md §5 (Stock/StockMove).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// Sklad nomlari — loyihaning boshqa joylaridagi (yuk_home_ui, bugalter_home_ui)
// hardcode map bilan bir xil.
const Map<int, String> kProductionSkladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
  4: 'Personal Sklad',
};

String productionSkladName(int id) =>
    kProductionSkladNames[id] ?? 'Sklad $id';

// SharedPreferences'dagi 'user' JSON ichidan foydalanuvchiga biriktirilgan
// skladlar ro'yxatini o'qish (yuk_home_ui dagi naqsh bilan bir xil).
Future<List<int>> loadUserSklads() async {
  final prefs = await SharedPreferences.getInstance();
  final userStr = prefs.getString('user');
  final sklads = <int>[];
  if (userStr != null && userStr.isNotEmpty) {
    try {
      final user = jsonDecode(userStr);
      if (user is Map && user['sklads'] is List) {
        for (final s in user['sklads']) {
          if (s is int) {
            sklads.add(s);
          } else if (s is num) {
            sklads.add(s.toInt());
          } else {
            final parsed = int.tryParse(s.toString());
            if (parsed != null) sklads.add(parsed);
          }
        }
      }
    } catch (_) {
      // Buzilgan JSON — bo'sh ro'yxat qaytadi.
    }
  }
  return sklads;
}

// GET /api/stock javobidagi bitta qator — (sklad, mahsulot) joriy qoldig'i.
class StockRow {
  final int skladId;
  final int productId;
  final String name;
  final String type; // mahsulotning o'z birligi: кг | литр | шт | м ...
  final double qty; // manfiy bo'lishi mumkin (qizil ko'rsatiladi)

  const StockRow({
    required this.skladId,
    required this.productId,
    this.name = '',
    this.type = '',
    this.qty = 0,
  });

  factory StockRow.fromJson(Map<String, dynamic> json) {
    return StockRow(
      skladId: _asInt(json['sklad_id']),
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      qty: _asDouble(json['qty']),
    );
  }

  static List<StockRow> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => StockRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Harakat sabablari (StockMove.reason qiymatlari).
abstract final class StockReason {
  static const String omborQabul = 'ombor_qabul';
  static const String ishlabChiqarish = 'ishlab_chiqarish';
  static const String korreksiya = 'korreksiya';
}

// Sabab kodini foydalanuvchiga ko'rsatiladigan matnga aylantirish.
String stockReasonLabel(String reason) {
  switch (reason) {
    case StockReason.omborQabul:
      return 'Kirim (qabul)';
    case StockReason.ishlabChiqarish:
      return 'Ishlab chiqarish';
    case StockReason.korreksiya:
      return 'Korreksiya';
    default:
      return reason;
  }
}

// GET /api/stock/moves javobidagi bitta harakat (mahsulot nomi bilan).
class StockMove {
  final int id;
  final int skladId;
  final int productId;
  final String name;
  final double qty; // + kirim, − chiqim
  final String reason; // ombor_qabul | ishlab_chiqarish | korreksiya
  final int refOrderId;
  final int userId;
  final String comment;
  final String created;

  const StockMove({
    required this.id,
    required this.skladId,
    required this.productId,
    this.name = '',
    this.qty = 0,
    this.reason = '',
    this.refOrderId = 0,
    this.userId = 0,
    this.comment = '',
    this.created = '',
  });

  factory StockMove.fromJson(Map<String, dynamic> json) {
    return StockMove(
      id: _asInt(json['id']),
      skladId: _asInt(json['sklad_id']),
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      qty: _asDouble(json['qty']),
      reason: json['reason']?.toString() ?? '',
      refOrderId: _asInt(json['ref_order_id']),
      userId: _asInt(json['user_id']),
      comment: json['comment']?.toString() ?? '',
      created: json['created']?.toString() ?? '',
    );
  }

  static List<StockMove> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => StockMove.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Korreksiya dialogidagi katalog elementi (qoldiqda hali yo'q mahsulotlar
// uchun — boshlang'ich qoldiq kiritish). /api/ombor/products dan yig'iladi.
class CatalogProduct {
  final int id;
  final String name;
  final String type;

  const CatalogProduct({required this.id, required this.name, this.type = ''});
}

// Miqdorni chiroyli ko'rsatish: 7.0 -> "7", 7.25 -> "7.25".
String fmtStockQty(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
