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

  // copyWith
  CategoryProductAdmin copyWith({
    int? id,
    String? name,
    String? imageUrl,
    int? printerId,
  }) {
    return CategoryProductAdmin(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      printerId: printerId ?? this.printerId,
    );
  }
}
