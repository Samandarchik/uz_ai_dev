// admin/model/category_model.dart — admin kategoriya modeli
// (CategoryProductAdmin): fromJson/toJson/copyWith. printer — CHEK-GURUH
// raqami (bir xil raqamlilar bitta chekda), printer_agent/printer_name —
// chek qaysi agentda (Windows kompyuter) va qaysi real printerda chiqadi
// (bo'sh = standart).
class CategoryProductAdmin {
  final int id;
  final String name;
  final String? imageUrl;
  final int printerId;
  final String? printerAgent;
  final String? printerName;

  CategoryProductAdmin({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.printerId,
    this.printerAgent,
    this.printerName,
  });
  //  toJson

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'printer': printerId,
      'printer_agent': printerAgent ?? '',
      'printer_name': printerName ?? '',
    };
  }

  static CategoryProductAdmin fromJson(Map<String, dynamic> json) {
    return CategoryProductAdmin(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      printerId: (json['printer'] as num?)?.toInt() ?? 1,
      printerAgent: json['printer_agent'],
      printerName: json['printer_name'],
    );
  }

  // copyWith
  CategoryProductAdmin copyWith({
    int? id,
    String? name,
    String? imageUrl,
    int? printerId,
    String? printerAgent,
    String? printerName,
  }) {
    return CategoryProductAdmin(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      printerId: printerId ?? this.printerId,
      printerAgent: printerAgent ?? this.printerAgent,
      printerName: printerName ?? this.printerName,
    );
  }
}
