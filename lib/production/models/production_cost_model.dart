// Tannarx (себестоимость) modellari — GET /api/production/cost javobi.
// Narx manbai: eng so'nggi narxlangan sklad-buyurtma itemi
// (unit_price = subtotal / taken). Kontrakt: mone_app/reja.md §F3.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// Bitta masalliq/расходник qatori (miqdor — 1 PARTIYA uchun, stock birligida).
class ProductionCostItem {
  final int productId;
  final String name;
  final String stockUnit; // кг | литр | шт | м ...
  final double amount; // 1 partiya uchun miqdor (stock birligida)
  final double unitPrice; // 1 birlik narxi (so'm)
  final double cost; // amount * unitPrice (so'm)
  final bool hasPrice; // false — narxlangan buyurtma topilmadi
  final String lastPriced; // oxirgi narxlangan sana ('' bo'lishi mumkin)

  const ProductionCostItem({
    this.productId = 0,
    required this.name,
    this.stockUnit = '',
    this.amount = 0,
    this.unitPrice = 0,
    this.cost = 0,
    this.hasPrice = false,
    this.lastPriced = '',
  });

  factory ProductionCostItem.fromJson(Map<String, dynamic> json) {
    return ProductionCostItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      stockUnit: json['stock_unit']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      unitPrice: _asDouble(json['unit_price']),
      cost: _asDouble(json['cost']),
      hasPrice: json['has_price'] == true,
      lastPriced: json['last_priced']?.toString() ?? '',
    );
  }

  static List<ProductionCostItem> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) =>
              ProductionCostItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Mahsulot tannarxi: 1 partiya (batch_qty dona) va 1 dona.
class ProductionCost {
  final int productId;
  final String name;
  final int batchQty; // partiyada nechta dona
  final double batchCost; // 1 partiya tannarxi (so'm)
  final double pieceCost; // 1 dona MASALLIQ tannarxi (so'm)
  final double overheadCost; // 1 dona dop. rasxod (so'm), 0 — yo'q
  final double fullPieceCost; // 1 dona TO'LIQ tannarx (so'm)
  final int salePrice; // tasdiqlangan sotish narxi (so'm), 0 — yo'q
  final int missing; // narxi yo'q masalliqlar soni
  final List<ProductionCostItem> items;

  const ProductionCost({
    required this.productId,
    this.name = '',
    this.batchQty = 1,
    this.batchCost = 0,
    this.pieceCost = 0,
    this.overheadCost = 0,
    this.fullPieceCost = 0,
    this.salePrice = 0,
    this.missing = 0,
    this.items = const [],
  });

  factory ProductionCost.fromJson(Map<String, dynamic> json) {
    final bq = _asInt(json['batch_qty']);
    return ProductionCost(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      batchQty: bq < 1 ? 1 : bq,
      batchCost: _asDouble(json['batch_cost']),
      pieceCost: _asDouble(json['piece_cost']),
      overheadCost: _asDouble(json['overhead_cost']),
      fullPieceCost: _asDouble(json['full_piece_cost']),
      salePrice: _asInt(json['sale_price']),
      missing: _asInt(json['missing']),
      items: ProductionCostItem.listFromJson(json['items']),
    );
  }
}
