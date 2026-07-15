// Qo'shimcha yozuv (proche mahsulot / rasxod) qo'shayotganda "Nomi" maydonida
// chiqadigan taklif. Manba: katalogdagi mahsulot nomlari + ilgari yuk
// keltiruvchilar qo'lda yozgan nomlar.
// MUHIM: taklif tanlash katalogga HECH NARSA qo'shmaydi — bu shunchaki
// qulaylik, foydalanuvchi istalgan yangi nomni qo'lda yozaverishi mumkin.
class ProcheNameSuggestion {
  final String name;
  // Katalog mahsuloti bo'lsa uning birligi (кг, шт, ...); aks holda bo'sh.
  final String type;
  // true — katalogda bor mahsulot, false — ilgari qo'lda yozilgan nom.
  final bool inCatalog;
  // Shu nom ilgari necha marta yozilgan (katalog nomlari uchun 0).
  final int uses;

  const ProcheNameSuggestion({
    required this.name,
    this.type = '',
    this.inCatalog = false,
    this.uses = 0,
  });

  factory ProcheNameSuggestion.fromJson(Map<String, dynamic> json) =>
      ProcheNameSuggestion(
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        inCatalog: json['in_catalog'] == true,
        uses: (json['uses'] as num?)?.toInt() ?? 0,
      );
}

// GET /api/yuk/proche-names javobidagi data ro'yxatini parse qiladi.
// Ro'yxat backenddan uses bo'yicha kamayuvchi tartibda keladi — tartib
// saqlanadi (bo'sh nomlar tashlab yuboriladi).
List<ProcheNameSuggestion> parseProcheNames(dynamic data) {
  if (data is! List) return [];
  final result = <ProcheNameSuggestion>[];
  for (final e in data) {
    if (e is! Map) continue;
    final item = ProcheNameSuggestion.fromJson(Map<String, dynamic>.from(e));
    if (item.name.isNotEmpty) result.add(item);
  }
  return result;
}
