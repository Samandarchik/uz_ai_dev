// Foyda analitikasi modellari — GET /api/analytics/profit?days=N
// (admin/bugalter, days ∈ {7,30,90}). Tortlar bo'yicha tushum/tannarx/foyda,
// kunlik marja dinamikasi va masalliq narx sakrashlari.
//
// Eslatma: marja HOZIRGI sotish narxi (sale_price) bilan butun davr uchun
// hisoblanadi; tannarx — o'sha kungi oxirgi kirim narxi. Narxlar eng kichik
// birlik uchun (кг/л -> 1 gr/ml) — UI'da x1000 qilib ko'rsatiladi.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// null bo'lishi mumkin bo'lgan son (masalan, marja hisoblanmagan kun).
double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

// null yoki bo'sh sana — null (masalan, minusga tushmagan tort).
String? _asDateOrNull(dynamic v) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? null : s;
}

List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return [];
}

// Bitta kunlik nuqta: o'sha kungi tannarx, marja (null — hisoblanmagan)
// va sotilgan dona.
class ProfitDailyPoint {
  final String d; // YYYY-MM-DD
  final double cost;
  final double? margin; // %, null — marja yo'q (narx belgilanmagan)
  final double qty;

  const ProfitDailyPoint({
    this.d = '',
    this.cost = 0,
    this.margin,
    this.qty = 0,
  });

  factory ProfitDailyPoint.fromJson(Map<String, dynamic> json) =>
      ProfitDailyPoint(
        d: json['d']?.toString() ?? '',
        cost: _asDouble(json['cost']),
        margin: _asDoubleOrNull(json['margin']),
        qty: _asDouble(json['qty']),
      );
}

// Bitta tort bo'yicha davr yakuni + kunlik dinamika.
class ProfitCake {
  final int productId;
  final String name;
  final double salePrice; // hozirgi sotish narxi (0 — belgilanmagan)
  final double sold; // sotilgan dona (filial buyurtmalari)
  final double revenue;
  final double cost;
  final double profit;
  final double? marginStart; // davr boshidagi marja %, null — yo'q
  final double? marginEnd; // davr oxiridagi marja %, null — yo'q
  final String? below20; // marja 20% dan pastga tushgan sana
  final String? negative; // marja minusga o'tgan sana
  final List<ProfitDailyPoint> daily;

  const ProfitCake({
    this.productId = 0,
    this.name = '',
    this.salePrice = 0,
    this.sold = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.marginStart,
    this.marginEnd,
    this.below20,
    this.negative,
    this.daily = const [],
  });

  factory ProfitCake.fromJson(Map<String, dynamic> json) => ProfitCake(
        productId: _asInt(json['product_id']),
        name: json['name']?.toString() ?? '',
        salePrice: _asDouble(json['sale_price']),
        sold: _asDouble(json['sold']),
        revenue: _asDouble(json['revenue']),
        cost: _asDouble(json['cost']),
        profit: _asDouble(json['profit']),
        marginStart: _asDoubleOrNull(json['margin_start']),
        marginEnd: _asDoubleOrNull(json['margin_end']),
        below20: _asDateOrNull(json['below20']),
        negative: _asDateOrNull(json['negative']),
        daily: _list(json['daily'], ProfitDailyPoint.fromJson),
      );
}

// Masalliq kirim narxining sakrashi (≥5% o'zgarish, top 10).
class ProfitPriceEvent {
  final String date;
  final int productId;
  final String name;
  final double oldPrice; // eng kichik birlik narxi (1 gr/ml)
  final double newPrice;
  final double changePct; // +25.0 — oshgan, manfiy — tushgan

  const ProfitPriceEvent({
    this.date = '',
    this.productId = 0,
    this.name = '',
    this.oldPrice = 0,
    this.newPrice = 0,
    this.changePct = 0,
  });

  factory ProfitPriceEvent.fromJson(Map<String, dynamic> json) =>
      ProfitPriceEvent(
        date: json['date']?.toString() ?? '',
        productId: _asInt(json['product_id']),
        name: json['name']?.toString() ?? '',
        oldPrice: _asDouble(json['old_price']),
        newPrice: _asDouble(json['new_price']),
        changePct: _asDouble(json['change_pct']),
      );
}

// Davr yakuni (barcha tortlar yig'indisi).
class ProfitTotals {
  final double revenue;
  final double cost;
  final double profit;
  final double sold;
  final int negativeCount; // minusga tushgan tortlar soni

  const ProfitTotals({
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.sold = 0,
    this.negativeCount = 0,
  });

  factory ProfitTotals.fromJson(Map<String, dynamic> json) => ProfitTotals(
        revenue: _asDouble(json['revenue']),
        cost: _asDouble(json['cost']),
        profit: _asDouble(json['profit']),
        sold: _asDouble(json['sold']),
        negativeCount: _asInt(json['negative_count']),
      );
}

// To'liq analitika javobi.
class ProfitAnalytics {
  final String from; // YYYY-MM-DD
  final String to;
  final List<String> days; // davrning barcha kunlari (X o'qi)
  final List<ProfitCake> cakes;
  final List<ProfitPriceEvent> events;
  final ProfitTotals totals;

  const ProfitAnalytics({
    this.from = '',
    this.to = '',
    this.days = const [],
    this.cakes = const [],
    this.events = const [],
    this.totals = const ProfitTotals(),
  });

  factory ProfitAnalytics.fromJson(Map<String, dynamic> json) {
    return ProfitAnalytics(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      days: (json['days'] is List)
          ? (json['days'] as List).map((e) => e.toString()).toList()
          : const [],
      cakes: _list(json['cakes'], ProfitCake.fromJson),
      events: _list(json['events'], ProfitPriceEvent.fromJson),
      totals: (json['totals'] is Map)
          ? ProfitTotals.fromJson(Map<String, dynamic>.from(json['totals']))
          : const ProfitTotals(),
    );
  }
}
