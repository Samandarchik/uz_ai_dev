// Ishlab chiqarish statistikasi modellari — GET /api/production/stats
// javobi (admin/bugalter). Kontrakt: mone_app/reja.md §F6.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
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

// Mahsulot bo'yicha: buyurtma qilingan / tayyor dona.
class StatsByProduct {
  final int productId;
  final String name;
  final int ordered;
  final int done;

  const StatsByProduct({
    this.productId = 0,
    this.name = '',
    this.ordered = 0,
    this.done = 0,
  });

  factory StatsByProduct.fromJson(Map<String, dynamic> json) => StatsByProduct(
        productId: _asInt(json['product_id']),
        name: json['name']?.toString() ?? '',
        ordered: _asInt(json['ordered']),
        done: _asInt(json['done']),
      );
}

// Shef bo'yicha: buyurtmalar va donalar.
class StatsByShef {
  final int shefId;
  final String shefName;
  final int orders;
  final int piecesOrdered;
  final int piecesDone;

  const StatsByShef({
    this.shefId = 0,
    this.shefName = '',
    this.orders = 0,
    this.piecesOrdered = 0,
    this.piecesDone = 0,
  });

  factory StatsByShef.fromJson(Map<String, dynamic> json) => StatsByShef(
        shefId: _asInt(json['shef_id']),
        shefName: json['shef_name']?.toString() ?? '',
        orders: _asInt(json['orders']),
        piecesOrdered: _asInt(json['pieces_ordered']),
        piecesDone: _asInt(json['pieces_done']),
      );
}

// Kun bo'yicha: shu kuni tayyor bo'lgan donalar (oxirgi bo'lim done_at).
class StatsByDay {
  final String date; // YYYY-MM-DD
  final int piecesDone;

  const StatsByDay({this.date = '', this.piecesDone = 0});

  factory StatsByDay.fromJson(Map<String, dynamic> json) => StatsByDay(
        date: json['date']?.toString() ?? '',
        piecesDone: _asInt(json['pieces_done']),
      );
}

// Bo'lim tezligi: ketma-ket done_at farqlarining o'rtachasi (soat).
class StatsStageAvg {
  final String name;
  final double avgHours;
  final int count;

  const StatsStageAvg({this.name = '', this.avgHours = 0, this.count = 0});

  factory StatsStageAvg.fromJson(Map<String, dynamic> json) => StatsStageAvg(
        name: json['name']?.toString() ?? '',
        avgHours: _asDouble(json['avg_hours']),
        count: _asInt(json['count']),
      );
}

// To'liq statistika javobi.
class ProductionStats {
  final int ordersTotal;
  final int ordersTayyor;
  final int piecesOrdered;
  final int piecesDone;
  final List<StatsByProduct> byProduct;
  final List<StatsByShef> byShef;
  final List<StatsByDay> byDay;
  final List<StatsStageAvg> stageAvgHours;

  const ProductionStats({
    this.ordersTotal = 0,
    this.ordersTayyor = 0,
    this.piecesOrdered = 0,
    this.piecesDone = 0,
    this.byProduct = const [],
    this.byShef = const [],
    this.byDay = const [],
    this.stageAvgHours = const [],
  });

  factory ProductionStats.fromJson(Map<String, dynamic> json) {
    return ProductionStats(
      ordersTotal: _asInt(json['orders_total']),
      ordersTayyor: _asInt(json['orders_tayyor']),
      piecesOrdered: _asInt(json['pieces_ordered']),
      piecesDone: _asInt(json['pieces_done']),
      byProduct: _list(json['by_product'], StatsByProduct.fromJson),
      byShef: _list(json['by_shef'], StatsByShef.fromJson),
      byDay: _list(json['by_day'], StatsByDay.fromJson),
      stageAvgHours: _list(json['stage_avg_hours'], StatsStageAvg.fromJson),
    );
  }
}
