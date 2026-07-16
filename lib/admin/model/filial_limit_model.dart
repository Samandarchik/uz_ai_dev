// Filial limiti — «bu mahsulotdan shu filialda doim N ta turishi kerak»
// qoidasi. Kechqurun tashqi POS kamomadni avtomatik buyurtma qiladi.
//
// MUHIM (gram kontrakt): limit_qty — saqlanadigan birlikdagi BUTUN son.
// кг/л mahsulotlarda bu gr/ml (1.5 kg -> 1500), шт va boshqalarda oddiy
// dona soni. UI ga chiqarishda qtyToUi/formatQty bilan qaytariladi.
class FilialLimit {
  final int id;
  final int filialId;
  final int productId;
  final String productName;
  final String unit;
  final int limitQty;
  final DateTime? updated;

  FilialLimit({
    required this.id,
    required this.filialId,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.limitQty,
    this.updated,
  });

  factory FilialLimit.fromJson(Map<String, dynamic> json) {
    return FilialLimit(
      id: (json['id'] as num?)?.toInt() ?? 0,
      filialId: (json['filial_id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name'] ?? '',
      unit: json['unit'] ?? '',
      limitQty: (json['limit_qty'] as num?)?.toInt() ?? 0,
      updated: json['updated'] != null
          ? DateTime.tryParse(json['updated'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filial_id': filialId,
      'product_id': productId,
      'product_name': productName,
      'unit': unit,
      'limit_qty': limitQty,
      'updated': updated?.toIso8601String(),
    };
  }
}
