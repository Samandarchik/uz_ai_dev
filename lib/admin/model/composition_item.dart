// Mahsulot tarkibidagi bitta ingredient (composition item).
// Backend JSON: { "product_id": 12, "name": "Сахар", "amount": 1500, "unit": "г" }
class CompositionItem {
  final int productId;
  final String name;
  final double amount;
  final String unit;

  CompositionItem({
    required this.productId,
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory CompositionItem.fromJson(Map<String, dynamic> json) {
    return CompositionItem(
      productId: (json['product_id'] is num)
          ? (json['product_id'] as num).toInt()
          : int.tryParse(json['product_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      unit: json['unit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  CompositionItem copyWith({
    int? productId,
    String? name,
    double? amount,
    String? unit,
  }) {
    return CompositionItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }

  // JSON ro'yxatini (null bo'lishi mumkin) parse qiladi.
  static List<CompositionItem> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => CompositionItem.fromJson(e))
          .toList();
    }
    return [];
  }
}
