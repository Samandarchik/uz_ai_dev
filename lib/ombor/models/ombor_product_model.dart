// Bozor (ombor) mahsuloti modeli.
// Backend javobi source (manba) bo'yicha guruhlangan shaklda keladi:
// { "success": true, "message": "...", "data": { "samarqand": [ {...}, ... ], ... } }
// Kalitlar — xom source kodlari: "samarqand", "toshkent", "zagranitsa",
// hamda manbasi bo'sh/noma'lum mahsulotlar uchun "boshqa".

// Guruhlarning qat'iy ko'rsatish tartibi.
const List<String> omborSourceOrder = [
  'samarqand',
  'toshkent',
  'zagranitsa',
  'boshqa',
];

// Manba kodini foydalanuvchiga ko'rsatiladigan o'zbekcha nomga aylantirish.
String omborSourceLabel(String code) {
  switch (code) {
    case 'samarqand':
      return 'Samarqand';
    case 'toshkent':
      return 'Toshkent';
    case 'zagranitsa':
      return 'Zagranitsa';
    case 'boshqa':
      return 'Boshqa';
    default:
      return code;
  }
}

class OmborProduct {
  final int id;
  final String name;
  final String? type;
  final num? grams;
  // Bozor (yuk keltiruvchi) oqimi uchun: 1 pachkaga qancha gramm
  final num? bozorGrams;
  final String? ingredients;
  final String? companyName;
  final String? imageUrl;
  final String? source;

  OmborProduct({
    required this.id,
    required this.name,
    this.type,
    this.grams,
    this.bozorGrams,
    this.ingredients,
    this.companyName,
    this.imageUrl,
    this.source,
  });

  factory OmborProduct.fromJson(Map<String, dynamic> json) {
    return OmborProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'],
      grams: json['grams'],
      bozorGrams: json['bozor_grams'],
      ingredients: json['ingredients'],
      companyName: json['company_name'],
      imageUrl: json['image_url'],
      source: json['source'],
    );
  }

  // Manba kodini foydalanuvchiga ko'rsatiladigan matnga aylantirish.
  String get sourceLabel => omborSourceLabel(source ?? '');
}

// Guruhlangan javobni ( data: Map<String, List> ) parse qilish.
// Kalitlar — source kodlari (samarqand/toshkent/zagranitsa/boshqa).
Map<String, List<OmborProduct>> parseOmborProducts(
    Map<String, dynamic> data) {
  final Map<String, List<OmborProduct>> result = {};
  data.forEach((source, products) {
    if (products is List) {
      result[source] = products
          .map((item) =>
              OmborProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  });
  return result;
}
