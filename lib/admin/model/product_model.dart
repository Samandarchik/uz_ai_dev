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
