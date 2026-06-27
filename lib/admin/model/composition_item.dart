// Mahsulot tarkibidagi bitta ingredient (composition item).
// Backend JSON: { "product_id": 12, "name": "Сахар", "amount": 1500, "unit": "г", "show_in_sostav": true }
class CompositionItem {
  final int productId;
  final String name;
  final double amount;
  final String unit;
  // Switch YONIQ bo'lsa shu ingredient nomi «Состав»ga chiqadi.
  final bool showInSostav;

  CompositionItem({
    required this.productId,
    required this.name,
    required this.amount,
    required this.unit,
    this.showInSostav = true,
  });

  factory CompositionItem.fromJson(Map<String, dynamic> json) {
    final rawShow = json['show_in_sostav'];
    return CompositionItem(
      productId: (json['product_id'] is num)
          ? (json['product_id'] as num).toInt()
          : int.tryParse(json['product_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      unit: json['unit']?.toString() ?? '',
      // Yo'q yoki null bo'lsa default true (eski/yangi itemlar ko'rinadi).
      showInSostav: rawShow == null ? true : rawShow == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'amount': amount,
      'unit': unit,
      'show_in_sostav': showInSostav,
    };
  }

  CompositionItem copyWith({
    int? productId,
    String? name,
    double? amount,
    String? unit,
    bool? showInSostav,
  }) {
    return CompositionItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      showInSostav: showInSostav ?? this.showInSostav,
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
