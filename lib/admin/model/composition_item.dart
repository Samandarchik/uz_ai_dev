// Mahsulot tarkibidagi bitta ingredient (composition item).
// Backend JSON: { "name": "Сахар", "amount": 1500, "unit": "г" }
class CompositionItem {
  final String name;
  final double amount;
  final String unit;

  CompositionItem({
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory CompositionItem.fromJson(Map<String, dynamic> json) {
    return CompositionItem(
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      unit: json['unit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  CompositionItem copyWith({
    String? name,
    double? amount,
    String? unit,
  }) {
    return CompositionItem(
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
