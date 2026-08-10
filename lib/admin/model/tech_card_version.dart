// admin/model/tech_card_version.dart — retsept (tex karta) tarixi yozuvi
// (TechCardVersionMeta): GET /api/products/{id}/tech-card/versions javobidagi
// bitta versiya META'si (kartaning o'zi yuborilmaydi — yengil ro'yxat).

class TechCardVersionMeta {
  final int id;
  final int productId;
  final DateTime? savedAt;

  /// Kartani O'ZGARTIRGAN (bu nusxani almashtirgan) foydalanuvchi.
  final String userName;

  /// Nusxa qaysi harakatda olingan: "tahrir" | "rollback" | "ochirish".
  final String action;

  /// Nima o'zgargani — serverdan tayyor o'zbekcha matn.
  final String summary;

  TechCardVersionMeta({
    required this.id,
    required this.productId,
    required this.savedAt,
    required this.userName,
    required this.action,
    required this.summary,
  });

  factory TechCardVersionMeta.fromJson(Map<String, dynamic> json) {
    return TechCardVersionMeta(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? ''),
      userName: json['user_name']?.toString() ?? '-',
      action: json['action']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
    );
  }
}
