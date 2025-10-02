class ProductModelAdmin {
  final int id;
  final String name;
  final int categoryId;
  final String type;
  final String categoryName;
  final String? imageUrl;
  final List<int> filials;
  final List<String> filialNames;

  ProductModelAdmin({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    required this.categoryName,
    this.imageUrl,
    required this.filials,
    required this.filialNames,
  });

  factory ProductModelAdmin.fromJson(Map<String, dynamic> json) {
    return ProductModelAdmin(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      type: json['type'] ?? '',
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
      'image_url': imageUrl,
      'category_name': categoryName,
      'filials': filials,
      'filial_names': filialNames,
    };
  }

  // Create uchun faqat kerakli maydonlar
  Map<String, dynamic> toCreateJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
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
      'category_id': categoryId,
      'type': type,
      "image_url": imageUrl,
      'filials': filials,
    };
  }

  ProductModelAdmin copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? type,
    String? categoryName,
    List<int>? filials,
    String? imageUrl,
    List<String>? filialNames,
  }) {
    return ProductModelAdmin(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      categoryName: categoryName ?? this.categoryName,
      filials: filials ?? this.filials,
      imageUrl: imageUrl ?? this.imageUrl,
      filialNames: filialNames ?? this.filialNames,
    );
  }
}
