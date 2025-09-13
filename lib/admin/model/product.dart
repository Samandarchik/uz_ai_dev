class ProductModel {
  final int id;
  final String name;
  final int categoryId;
  final String type;
  final String categoryName;
  final List<int> filials;
  final List<String> filialNames;

  ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    required this.categoryName,
    required this.filials,
    required this.filialNames,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      type: json['type'] ?? '',
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
      'category_name': categoryName,
      'filials': filials,
      'filial_names': filialNames,
    };
  }

  // Create uchun faqat kerakli maydonlar
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'category_id': categoryId,
      'type': type,
      'filials': filials,
    };
  }

  // Update uchun faqat kerakli maydonlar
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'category_id': categoryId,
      'type': type,
      'filials': filials,
    };
  }

  ProductModel copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? type,
    String? categoryName,
    List<int>? filials,
    List<String>? filialNames,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      categoryName: categoryName ?? this.categoryName,
      filials: filials ?? this.filials,
      filialNames: filialNames ?? this.filialNames,
    );
  }
}