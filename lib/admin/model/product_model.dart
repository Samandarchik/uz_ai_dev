class AdminFilialModel {
  final String name;

  AdminFilialModel({required this.name});

  factory AdminFilialModel.fromJson(Map<String, dynamic> json) {
    return AdminFilialModel(name: json['name'] ?? '');
  }
}

class CategoryProductAdmin {
  final int id;
  final String name;
  final String? imageUrl;
  final int printerId;

  CategoryProductAdmin(
      {required this.id,
      required this.name,
      required this.imageUrl,
      required this.printerId});
  //  toJson

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'printer': printerId,
    };
  }

  static CategoryProductAdmin fromJson(Map<String, dynamic> json) {
    return CategoryProductAdmin(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      printerId: json['printer'],
    );
  }
}
