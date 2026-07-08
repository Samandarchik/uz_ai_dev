// Yuk keltiruvchining kunlik hisob daftari yozuvi.
// GET /api/yuk/ledger dan keladi:
// { "date":"2026-07-05", "opening":180000, "prixod":500000,
//   "rasxod":320000, "yuborilgan":250000, "closing":430000 }
class YukLedgerDay {
  final String date; // "YYYY-MM-DD" ko'rinishida
  final num opening; // ertalabgi ostatok
  final num prixod; // kun davomida berilgan pul
  // Hali yuborilmagan (qoralama) summalar — real time, balansga kirmaydi.
  final num rasxod;
  // Yuborilgan (narxlandi/qabul_qilindi) buyurtmalar summasi — balans shu
  // bilan yuradi: itog = opening - yuborilgan.
  final num yuborilgan;
  final num closing; // kechki ostatok = opening + prixod - yuborilgan

  const YukLedgerDay({
    required this.date,
    required this.opening,
    required this.prixod,
    required this.rasxod,
    required this.yuborilgan,
    required this.closing,
  });

  // Itog = ertalabgi ostatok - yuborilgan buyurtmalar summasi.
  num get itog => opening - yuborilgan;

  factory YukLedgerDay.fromJson(Map<String, dynamic> json) {
    return YukLedgerDay(
      date: json['date']?.toString() ?? '',
      opening: (json['opening'] as num?) ?? 0,
      prixod: (json['prixod'] as num?) ?? 0,
      rasxod: (json['rasxod'] as num?) ?? 0,
      yuborilgan: (json['yuborilgan'] as num?) ?? 0,
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

// ───────────── Kun tafsiloti: GET /api/yuk/ledger/day?date=... ─────────────
// Bitta kunda pul nimaga sarflangani: yuborilgan buyurtmalar (itemlari bilan)
// va o'sha kuni yangilangan, hali yuborilmagan qoralamalar.

// Buyurtma ichidagi bitta yozuv.
// item_type: '' — katalog mahsuloti, 'proche' — qo'lda qo'shilgan mahsulot,
// 'rasxod' — xarajat/xizmat.
class LedgerDayItem {
  final String name;
  final double taken;
  final num subtotal;
  final String itemType;

  const LedgerDayItem({
    required this.name,
    required this.taken,
    required this.subtotal,
    required this.itemType,
  });

  bool get isRasxod => itemType == 'rasxod';

  factory LedgerDayItem.fromJson(Map<String, dynamic> json) {
    return LedgerDayItem(
      name: json['name']?.toString() ?? '',
      taken: (json['taken'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?) ?? 0,
      itemType: json['item_type']?.toString() ?? '',
    );
  }
}

// Kun ichidagi bitta buyurtma (yuborilgan yoki qoralama).
class LedgerDayOrder {
  final int id;
  final String orderId;
  final String skladName;
  final String status;
  final String created; // RFC3339
  final DateTime? pricedAt; // narxlangan vaqt; "nol" vaqt bo'lsa null
  final num total;
  final num expensesTotal;
  final List<LedgerDayItem> items;

  const LedgerDayOrder({
    required this.id,
    required this.orderId,
    required this.skladName,
    required this.status,
    required this.created,
    required this.pricedAt,
    required this.total,
    required this.expensesTotal,
    required this.items,
  });

  // Yuborilgan (balansga kirgan) buyurtmami.
  bool get isDone => status == 'narxlandi' || status == 'qabul_qilindi';

  // Ko'rsatiladigan vaqt: narxlangan vaqti bo'lsa o'sha, aks holda yaratilgani.
  DateTime? get displayTime => pricedAt ?? DateTime.tryParse(created);

  // Chek jami — itemlar yig'indisi (total 0 bo'lib kelishi mumkin).
  num get itemsSum {
    num sum = 0;
    for (final it in items) {
      sum += it.subtotal;
    }
    return sum;
  }

  // Go time.Time: bo'sh yoki "0001-01-01..." (yil <= 1) — null.
  static DateTime? _parseTime(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null || dt.year <= 1) return null;
    return dt;
  }

  factory LedgerDayOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return LedgerDayOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: json['order_id']?.toString() ?? '',
      skladName: json['sklad_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      created: json['created']?.toString() ?? '',
      pricedAt: _parseTime(json['priced_at']),
      total: (json['total'] as num?) ?? 0,
      expensesTotal: (json['expenses_total'] as num?) ?? 0,
      items: [
        if (rawItems is List)
          for (final v in rawItems)
            if (v is Map) LedgerDayItem.fromJson(Map<String, dynamic>.from(v)),
      ],
    );
  }
}

// Bitta kunning to'liq tafsiloti.
class LedgerDayDetail {
  final String date; // "YYYY-MM-DD"
  final num yuborilgan; // kunning balansga kirgan rasxodi
  final num prixod; // kunda berilgan pul
  final List<LedgerDayOrder> orders;

  const LedgerDayDetail({
    required this.date,
    required this.yuborilgan,
    required this.prixod,
    required this.orders,
  });

  // Yuborilgan buyurtmalar — yig'indisi yuborilgan'ga teng.
  List<LedgerDayOrder> get doneOrders =>
      [for (final o in orders) if (o.isDone) o];

  // Hali yuborilmagan qoralamalar — kun jamiga KIRMAYDI.
  List<LedgerDayOrder> get draftOrders =>
      [for (final o in orders) if (!o.isDone) o];

  factory LedgerDayDetail.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'];
    return LedgerDayDetail(
      date: json['date']?.toString() ?? '',
      yuborilgan: (json['yuborilgan'] as num?) ?? 0,
      prixod: (json['prixod'] as num?) ?? 0,
      orders: [
        if (rawOrders is List)
          for (final v in rawOrders)
            if (v is Map) LedgerDayOrder.fromJson(Map<String, dynamic>.from(v)),
      ],
    );
  }
}
