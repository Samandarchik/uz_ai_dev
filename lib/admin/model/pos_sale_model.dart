// POS (Konak) smena sotuvlari hisoboti — POS smena yopilganda mone'ga
// yuboradigan agregat sotuvlar.
// Kontrakt: GET /api/pos-sales?days=30[&filial_id=] (faqat admin) —
// data: {sales:[PosSale...], total:int} (total = ko'rsatilganlar summasi).
//
// MUHIM (gram kontrakt): qty API'da saqlanadigan birlikdagi BUTUN son —
// кг/л mahsulotlarda gr/ml (formatQtyUnit bilan ko'rsatiladi). Pul
// (total) — butun so'm (tiyin yo'q).

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

class PosSaleItem {
  final int productId;
  final String name;
  final String unit;
  final int qty; // saqlanadigan birlikda butun
  final int total; // butun so'm

  const PosSaleItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.total,
  });

  factory PosSaleItem.fromJson(Map<String, dynamic> json) {
    return PosSaleItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      qty: _asInt(json['qty']),
      total: _asInt(json['total']),
    );
  }
}

// Bitta smenaning sotuvlari (filial + smena + sana bo'yicha bitta yozuv).
class PosSale {
  final int id;
  final int filialId;
  final String filialName;
  final int shiftId;
  final String date; // "YYYY-MM-DD"
  final List<PosSaleItem> items;
  final int total; // butun so'm
  final DateTime? created;

  const PosSale({
    required this.id,
    required this.filialId,
    required this.filialName,
    required this.shiftId,
    required this.date,
    this.items = const [],
    this.total = 0,
    this.created,
  });

  factory PosSale.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PosSale(
      id: _asInt(json['id']),
      filialId: _asInt(json['filial_id']),
      filialName: json['filial_name']?.toString() ?? '',
      shiftId: _asInt(json['shift_id']),
      date: json['date']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => PosSaleItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      total: _asInt(json['total']),
      created: json['created'] == null
          ? null
          : DateTime.tryParse(json['created'].toString()),
    );
  }
}

// GET /api/pos-sales javobi: yozuvlar + umumiy summa.
class PosSalesResult {
  final List<PosSale> sales;
  final int total; // butun so'm

  const PosSalesResult({this.sales = const [], this.total = 0});

  factory PosSalesResult.fromJson(Map<String, dynamic> json) {
    final rawSales = json['sales'];
    return PosSalesResult(
      sales: rawSales is List
          ? rawSales
              .whereType<Map>()
              .map((e) => PosSale.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      total: _asInt(json['total']),
    );
  }
}
