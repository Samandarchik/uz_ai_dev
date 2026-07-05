// Yuk keltiruvchining kunlik hisob daftari yozuvi.
// GET /api/yuk/ledger dan keladi:
// { "date":"2026-07-05", "opening":180000, "prixod":500000,
//   "rasxod":320000, "closing":360000 }
class YukLedgerDay {
  final String date; // "YYYY-MM-DD" ko'rinishida
  final num opening; // ertalabgi ostatok
  final num prixod; // kun davomida berilgan pul
  final num rasxod; // kun davomida ishlatilgan pul
  final num closing; // kechki ostatok

  const YukLedgerDay({
    required this.date,
    required this.opening,
    required this.prixod,
    required this.rasxod,
    required this.closing,
  });

  factory YukLedgerDay.fromJson(Map<String, dynamic> json) {
    return YukLedgerDay(
      date: json['date']?.toString() ?? '',
      opening: (json['opening'] as num?) ?? 0,
      prixod: (json['prixod'] as num?) ?? 0,
      rasxod: (json['rasxod'] as num?) ?? 0,
      closing: (json['closing'] as num?) ?? 0,
    );
  }
}

// data ro'yxatini xavfsiz parse qilish (buzuq elementlar tashlab yuboriladi).
List<YukLedgerDay> parseYukLedger(dynamic data) {
  if (data is! List) return [];
  return [
    for (final v in data)
      if (v is Map) YukLedgerDay.fromJson(Map<String, dynamic>.from(v)),
  ];
}
