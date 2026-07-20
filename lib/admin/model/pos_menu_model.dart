// POS (Konak) menyu — POS ko'radigan katalog (kategoriyalar + mahsulotlar).
// Kontrakt: GET /api/pos-menu?filial_id=N (faqat admin, filial_id ixtiyoriy —
// server birinchi filialni oladi) — data:
// {filial_id, filial_name, categories:[{id,name}], products:[PosMenuProduct]}.
//
// MUHIM (int kontrakt): sale_price — butun so'm (0 = narx qo'yilmagan),
// limit_qty — saqlanadigan birlikdagi BUTUN son (кг/л -> gr/ml, 0 = limit
// yo'q; formatQtyUnit bilan ko'rsatiladi). image_url absolyut URL (bo'sh
// bo'lishi mumkin).

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

class PosMenuCategory {
  final int id;
  final String name;

  const PosMenuCategory({required this.id, required this.name});

  factory PosMenuCategory.fromJson(Map<String, dynamic> json) {
    return PosMenuCategory(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class PosMenuProduct {
  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final String unit;
  final int salePrice; // butun so'm (0 = narx qo'yilmagan)
  final String imageUrl; // absolyut URL (bo'sh bo'lishi mumkin)
  final int limitQty; // saqlanadigan birlikda butun (0 = limit yo'q)

  const PosMenuProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.salePrice,
    required this.imageUrl,
    required this.limitQty,
  });

  factory PosMenuProduct.fromJson(Map<String, dynamic> json) {
    return PosMenuProduct(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      categoryId: _asInt(json['category_id']),
      categoryName: json['category_name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      salePrice: _asInt(json['sale_price']),
      imageUrl: json['image_url']?.toString() ?? '',
      limitQty: _asInt(json['limit_qty']),
    );
  }
}

// GET /api/pos-menu javobi: filial + kategoriyalar + mahsulotlar.
class PosMenuResult {
  final int filialId;
  final String filialName;
  final List<PosMenuCategory> categories;
  final List<PosMenuProduct> products;

  const PosMenuResult({
    this.filialId = 0,
    this.filialName = '',
    this.categories = const [],
    this.products = const [],
  });

  factory PosMenuResult.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawProducts = json['products'];
    return PosMenuResult(
      filialId: _asInt(json['filial_id']),
      filialName: json['filial_name']?.toString() ?? '',
      categories: rawCategories is List
          ? rawCategories
              .whereType<Map>()
              .map((e) =>
                  PosMenuCategory.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      products: rawProducts is List
          ? rawProducts
              .whereType<Map>()
              .map((e) => PosMenuProduct.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
