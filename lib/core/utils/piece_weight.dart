// core/utils/piece_weight.dart — кг/л mahsulot nomidan «1 dona = X гр/мл» ni
// o'qish (pieceWeightFromName). Yuk keltiruvchi donalab olingan mahsulotni
// (masalan «Lactel масло 1шт=200гр») dona soni bilan kiritishi uchun —
// birlik (кг/л) va sklad qoldig'i o'zgarmaydi, faqat kiritish qulaylashadi.
//
// Nima uchun nomdan: katalogdagi 300+ кг/л mahsulot nomida «1шт=…»,
// «1 пачка=…», «(400гр)», «150 гр» ko'rinishida dona vazni yozilgan; bir kuni
// dona, bir kuni kg deb kiritilgani narxni 10–90 marta sakratardi (Berg вода:
// 100 @ 7 000 va 1.04 л @ 673 077). Aniq bo'lmagan nomlar («Помидоры 4Кг»,
// «(750гр) (400гр)», «2*5кг») ATAYLAB o'qilmaydi — null.
library;

import 'package:uz_ai_dev/core/utils/qty_units.dart';

final RegExp _explicit = RegExp(
  // Dart RegExp'da \b kirill harflari uchun ishlamaydi — o'rniga lookahead.
  r'1\s*(?:шт|щт|пачка|пач|мешок|лт|литр|л)\s*\.?\s*=\s*(\d+(?:[.,]\d+)?)\s*(кг|kg|грамм|гр|г|литр|лтир|лт|л|мл)(?![а-яёa-z0-9])',
  caseSensitive: false,
);
final RegExp _paren = RegExp(
  r'\((\d+(?:[.,]\d+)?)\s*(гр|г|мл)\)',
  caseSensitive: false,
);
final RegExp _trailingGram = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(гр|г)\.?\s*$',
  caseSensitive: false,
);
final RegExp _multiPack = RegExp(r'\d\s*\*\s*\d');

/// Nomdan bir dona vaznini (гр yoki мл) qaytaradi; o'qib bo'lmasa null.
/// Faqat кг/л birlikli mahsulot uchun (boshqa birlikda ma'nosiz).
int? pieceWeightFromName(String name, String? type) {
  if (qtyUnitFactor(type) != 1000) return null;
  if (_multiPack.hasMatch(name)) return null;

  final m = _explicit.firstMatch(name);
  if (m != null) return _toMilli(m.group(1)!, m.group(2)!);

  final parens = _paren.allMatches(name).toList();
  if (parens.length == 1) {
    return _toMilli(parens.first.group(1)!, parens.first.group(2)!);
  }
  if (parens.length > 1) return null; // «(750гр) (400гр)» — noaniq

  final t = _trailingGram.firstMatch(name);
  if (t != null) return _toMilli(t.group(1)!, t.group(2)!);
  return null;
}

/// «0,800гр» kabi yozuvlar — aslida kg (800 гр): гр birlikda 10 dan kichik
/// kasr qiymat kg deb o'qiladi. Natija 5 гр … 50 кг oralig'ida bo'lmasa null.
int? _toMilli(String rawValue, String unit) {
  final v = double.tryParse(rawValue.replaceAll(',', '.'));
  if (v == null || v <= 0) return null;
  final u = unit.toLowerCase();
  double milli;
  if (u == 'кг' || u == 'kg' || u.startsWith('л') || u == 'литр' || u == 'лтир' || u == 'лт') {
    milli = v * 1000;
  } else if ((u == 'гр' || u == 'г' || u == 'грамм') && v < 10 && rawValue.contains(RegExp(r'[.,]'))) {
    milli = v * 1000;
  } else {
    milli = v;
  }
  final r = milli.round();
  if (r < 5 || r > 50000) return null;
  return r;
}
