// Yuk keltiruvchining (bozorchining) "Qarz daftari" modellari.
// Magazin — bozorchi qarzdor bo'lgan do'kon (egasining ismi, do'kon nomi,
// telefon, rasm). MagazinDebt — shu magazinga yozilgan bitta qarz yozuvi.
// Backend JSON snake_case; raqamlar himoyalanib (num?) parse qilinadi.

class Magazin {
  final int id;
  final int userId;
  // Magazin egasining ismi (masalan "Ali aka").
  final String name;
  // Do'kon nomi (masalan "Ali savdo").
  final String shopName;
  final String phone;
  // Serverdagi relativ rasm URL ('/static/yuk/x.jpg') yoki bo'sh satr.
  final String imageUrl;
  final String created;
  // Shu magazinga jami qarz (yozuvlar yig'indisi). Kasr bo'lishi mumkin.
  final double totalDebt;

  const Magazin({
    required this.id,
    required this.userId,
    required this.name,
    required this.shopName,
    required this.phone,
    this.imageUrl = '',
    this.created = '',
    this.totalDebt = 0,
  });

  factory Magazin.fromJson(Map<String, dynamic> json) => Magazin(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        shopName: json['shop_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        imageUrl: json['image_url']?.toString() ?? '',
        created: json['created']?.toString() ?? '',
        totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0,
      );

  Magazin copyWith({
    String? name,
    String? shopName,
    String? phone,
    String? imageUrl,
    double? totalDebt,
  }) =>
      Magazin(
        id: id,
        userId: userId,
        name: name ?? this.name,
        shopName: shopName ?? this.shopName,
        phone: phone ?? this.phone,
        imageUrl: imageUrl ?? this.imageUrl,
        created: created,
        totalDebt: totalDebt ?? this.totalDebt,
      );
}

// Bitta qarz yozuvi. amount musbat — qarz qo'shildi; manfiy — to'lov
// (backend ruxsat beradi, UI hozircha faqat qarz qo'shadi).
class MagazinDebt {
  final int id;
  final int magazinId;
  final int userId;
  final double amount;
  final String comment;
  final DateTime? created;

  const MagazinDebt({
    required this.id,
    required this.magazinId,
    required this.userId,
    required this.amount,
    this.comment = '',
    this.created,
  });

  factory MagazinDebt.fromJson(Map<String, dynamic> json) => MagazinDebt(
        id: (json['id'] as num?)?.toInt() ?? 0,
        magazinId: (json['magazin_id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        comment: json['comment']?.toString() ?? '',
        created: DateTime.tryParse(json['created']?.toString() ?? ''),
      );
}

// GET /api/magazins data.magazins ro'yxatini parse qiladi.
List<Magazin> parseMagazins(dynamic data) {
  if (data is! List) return [];
  return [
    for (final e in data)
      if (e is Map) Magazin.fromJson(Map<String, dynamic>.from(e)),
  ];
}

// GET /api/magazins/{id}/debts data.debts ro'yxatini parse qiladi
// (backend eng yangisini birinchi qaytaradi).
List<MagazinDebt> parseMagazinDebts(dynamic data) {
  if (data is! List) return [];
  return [
    for (final e in data)
      if (e is Map) MagazinDebt.fromJson(Map<String, dynamic>.from(e)),
  ];
}
