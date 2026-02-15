class ProductModelAdmin {
  final int id;
  final String name;
  final int categoryId;
  final String type;
  final String? companyName;
  final num? grams;
  final String categoryName;
  final String? imageUrl;
  final String? ingredients;

  final List<int> filials;
  final List<String> filialNames;

  ProductModelAdmin({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    this.companyName,
    this.grams,
    required this.categoryName,
    this.ingredients,
    this.imageUrl,
    required this.filials,
    required this.filialNames,
  });

  factory ProductModelAdmin.fromJson(Map<String, dynamic> json) {
    return ProductModelAdmin(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      grams: json['grams'],
      type: json['type'] ?? '',
      ingredients: json['ingredients'],
      companyName: json['company_name'],
      imageUrl: json['image_url'],
      categoryName: json['category_name'] ?? '',
      filials: List<int>.from(json['filials'] ?? []),
      filialNames: List<String>.from(json['filial_names'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'type': type,
      'company_name': companyName,
      'ingredients': ingredients,
      'image_url': imageUrl,
      'category_name': categoryName,
      'filials': filials,
      'filial_names': filialNames,
      'grams': grams
    };
  }

  // Create uchun faqat kerakli maydonlar
  Map<String, dynamic> toCreateJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'ingredients': ingredients,
      "company_name": companyName,
      'grams': grams,
      'type': type,
      "image_url": imageUrl,
      'filials': filials,
    };
  }

  // Update uchun faqat kerakli maydonlar

  Map<String, dynamic> toUpdateJson() {
    return {
      'id': id,
      'name': name,
      'grams': grams,
      'category_id': categoryId,
      'type': type,
      "company_name": companyName,
      "ingredients": ingredients,
      "image_url": imageUrl,
      'filials': filials,
    };
  }

  ProductModelAdmin copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? type,
    num? grams,
    String? companyName,
    String? categoryName,
    String? ingredients,
    List<int>? filials,
    String? imageUrl,
    List<String>? filialNames,
  }) {
    return ProductModelAdmin(
      id: id ?? this.id,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      companyName: companyName ?? this.companyName,
      ingredients: ingredients ?? this.ingredients,
      categoryName: categoryName ?? this.categoryName,
      filials: filials ?? this.filials,
      imageUrl: imageUrl ?? this.imageUrl,
      filialNames: filialNames ?? this.filialNames,
    );
  }
}
