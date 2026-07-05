// Yuk keltiruvchi foydalanuvchi (bugalter pul berish uchun tanlaydi).
// GET /api/yuk-users dan keladi: { "id":37, "name":"...", "phone":"..." }
class YukUser {
  final int id;
  final String name;
  final String phone;

  const YukUser({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory YukUser.fromJson(Map<String, dynamic> json) {
    return YukUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

// data ro'yxatini xavfsiz parse qilish (buzuq elementlar tashlab yuboriladi).
List<YukUser> parseYukUsers(dynamic data) {
  if (data is! List) return [];
  return [
    for (final v in data)
      if (v is Map) YukUser.fromJson(Map<String, dynamic>.from(v)),
  ];
}
