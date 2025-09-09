// models/product_model.dart
class Product {
  final int id;
  final String name;
  final int count;
  final String? category;

  Product({
    required this.id,
    required this.name,
    required this.count,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      category: json['category'],
    );
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

  OrderItem({
    required this.productId,
    required this.count,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'count': count,
    };
  }
}
