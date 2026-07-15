// Xarid narxlari tarixi — GET /api/prices/history?product_id=N&limit=20
// javobi (eng yangisi birinchi). qty ENG KICHIK birlikda (кг/л -> gr/ml),
// price — eng kichik birlik narxi (UI'da 1 kg/l narxi uchun
// qtyUnitFactor(unit) ga ko'paytiriladi).

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

class PriceHistoryEntry {
  final DateTime? date;
  final String skladName;
  final String pricer; // narxlagan foydalanuvchi
  final double qty; // eng kichik birlikda
  final String unit; // Кг | Литр | шт | м ... (sklad birligi)
  final double price; // eng kichik birlik narxi (so'm)
  final double sum; // qty * price (so'm)

  const PriceHistoryEntry({
    this.date,
    this.skladName = '',
    this.pricer = '',
    this.qty = 0,
    this.unit = '',
    this.price = 0,
    this.sum = 0,
  });

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PriceHistoryEntry(
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      skladName: json['sklad_name']?.toString() ?? '',
      pricer: json['pricer']?.toString() ?? '',
      qty: _asDouble(json['qty']),
      unit: json['unit']?.toString() ?? '',
      price: _asDouble(json['price']),
      sum: _asDouble(json['sum']),
    );
  }

  static List<PriceHistoryEntry> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => PriceHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
