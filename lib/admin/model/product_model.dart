// models/product_model.dart
class Product {
  final int id;
  final String name;
  final int count;
  final String category;
  final int categoryId;
  final String? type;

  Product(
      {required this.id,
      required this.name,
      required this.count,
      required this.categoryId,
      required this.category,
      required this.type});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        count: json['count'] ?? 0,
        categoryId: json['category_id'] ?? 0,
        category: json['category'],
        type: json["type"] ?? "null");
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'count': count,
      'category': category,
    };
  }
}

class FilialNames {
  final String name;

  FilialNames({required this.name});

  factory FilialNames.fromJson(Map<String, dynamic> json) {
    return FilialNames(name: json['name'] ?? '');
  }
}

class CategoryProduct {
  final int id;
  final String name;

  CategoryProduct({required this.id, required this.name});
  //  toJson

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  static CategoryProduct fromJson(Map<String, dynamic> json) {
    return CategoryProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class SelectedProduct {
  final int productId;
  final String name;
  int count;

  SelectedProduct({
    required this.productId,
    required this.name,
    required this.count,
  });

  factory SelectedProduct.fromJson(Map<String, dynamic> json) {
    return SelectedProduct(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'count': count,
    };
  }
}

class OrderItem {
  final int productId;
  final int count;
  final String? type;
  OrderItem({required this.productId, required this.count, this.type});

  Map<String, dynamic> toJson() {
    return {'product_id': productId, 'count': count, 'type': type};
  }
}
