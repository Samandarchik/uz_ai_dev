// Oxirgi xarid narxlari — GET /api/prices/latest javobi.
// unit_price ENG KICHIK birlik narxi: кг/л mahsulotlar uchun 1 gr/ml,
// шт uchun 1 dona, м uchun 1 metr (so'm). Hech qachon narxlanmagan
// mahsulotlar ro'yxatda BO'LMAYDI. Tex karta muharriridagi jonli tannarx
// kataklari shu modeldan foydalanadi.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

class LatestPrice {
  final int productId;
  final double unitPrice; // eng kichik birlik narxi (so'm)
  final DateTime? lastPriced; // oxirgi narxlangan vaqt

  const LatestPrice({
    required this.productId,
    required this.unitPrice,
    this.lastPriced,
  });

  factory LatestPrice.fromJson(Map<String, dynamic> json) {
    return LatestPrice(
      productId: _asInt(json['product_id']),
      unitPrice: _asDouble(json['unit_price']),
      lastPriced: DateTime.tryParse(json['last_priced']?.toString() ?? ''),
    );
  }

  // Ro'yxatni product_id bo'yicha map'ga yig'adi (qatorlarga join uchun).
  static Map<int, LatestPrice> mapFromJson(dynamic data) {
    final map = <int, LatestPrice>{};
    if (data is List) {
      for (final e in data.whereType<Map>()) {
        final p = LatestPrice.fromJson(Map<String, dynamic>.from(e));
        if (p.productId != 0) map[p.productId] = p;
      }
    }
    return map;
  }
}
