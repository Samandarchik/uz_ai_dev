// Bozor (ombor) mahsuloti modeli.
// Backend javobi seller /products1 bilan bir xil guruhlangan shaklda keladi:
// { "success": true, "message": "...", "data": { "Kategoriya": [ {...}, ... ] } }

class OmborProduct {
  final int id;
  final String name;
  final String? type;
  final num? grams;
  final String? ingredients;
  final String? companyName;
  final String? imageUrl;
  final String? source;

  OmborProduct({
    required this.id,
    required this.name,
    this.type,
    this.grams,
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
      ingredients: json['ingredients'],
      companyName: json['company_name'],
      imageUrl: json['image_url'],
      source: json['source'],
    );
  }

  // Manba kodini foydalanuvchiga ko'rsatiladigan matnga aylantirish.
  String get sourceLabel {
    switch (source) {
      case 'samarqand':
        return 'Samarqand';
      case 'toshkent':
        return 'Toshkent';
      case 'zagranitsa':
        return 'Zagranitsa';
      default:
        return source ?? '';
    }
  }
}

// Guruhlangan javobni ( data: Map<String, List> ) parse qilish.
Map<String, List<OmborProduct>> parseOmborProducts(
    Map<String, dynamic> data) {
  final Map<String, List<OmborProduct>> result = {};
  data.forEach((category, products) {
    if (products is List) {
      result[category] = products
          .map((item) =>
              OmborProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  });
  return result;
}
