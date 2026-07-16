// Audit jurnali yozuvi modeli.
// Kontrakt: GET /api/audit-log[?limit=&entity=&action=] — admin harakatlari
// tarixi, eng yangisi birinchi. Faqat admin.
//
// old_value/new_value — backend TAYYOR matn qilib beradi (masalan
// "180 000 so'm"); UI ularni o'zgartirmasdan «eski → yangi» ko'rinishida
// ko'rsatadi. Ikkalasi ham bo'sh bo'lishi mumkin.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

class AuditLogEntry {
  final int id;
  final DateTime? created;
  final int userId;
  final String userName;
  final String userRole;
  // action: narx_ozgartirish | sklad_korreksiya | buyurtma_ochirish |
  //         qarz_yozish | qarz_ochirish | tolov_yaratish | tolov_ochirish
  final String action;
  // entity: product | stock | order | magazin_debt | payment
  final String entity;
  final int entityId;
  final String entityName;
  final String oldValue;
  final String newValue;
  final String comment;

  const AuditLogEntry({
    required this.id,
    this.created,
    this.userId = 0,
    this.userName = '',
    this.userRole = '',
    this.action = '',
    this.entity = '',
    this.entityId = 0,
    this.entityName = '',
    this.oldValue = '',
    this.newValue = '',
    this.comment = '',
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: _asInt(json['id']),
      created: DateTime.tryParse(json['created']?.toString() ?? ''),
      userId: _asInt(json['user_id']),
      userName: json['user_name']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      entity: json['entity']?.toString() ?? '',
      entityId: _asInt(json['entity_id']),
      entityName: json['entity_name']?.toString() ?? '',
      oldValue: json['old_value']?.toString() ?? '',
      newValue: json['new_value']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
    );
  }

  // Javob tanasidan ro'yxatni ochadi: {"success":true,"data":[...]} yoki
  // to'g'ridan-to'g'ri [...] kelsa ham ishlaydi.
  static List<AuditLogEntry> listFromJson(dynamic body) {
    final data = body is Map ? (body['data'] ?? body) : body;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => AuditLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
