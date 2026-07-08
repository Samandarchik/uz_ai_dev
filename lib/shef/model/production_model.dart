// Ishlab chiqarish (производство) modellari — shef roli.
// Backend JSON snake_case; kontrakt: mone_app/reja.md §5–6.
//
// Buyurtma yaratilganda tex kartadan SNAPSHOT olinadi, shuning uchun bu
// modellar tex karta modellaridan mustaqil.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// GET /api/production/products elementi — tex kartasi bor mahsulot
// (buyurtma yaratish sahifasidagi ro'yxat).
class ProductionProduct {
  final int id;
  final String name;
  final String imageUrl; // '/static/...' yoki to'liq URL yoki ''
  final int batchQty; // partiyada nechta dona (>= 1)

  const ProductionProduct({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.batchQty = 1,
  });

  factory ProductionProduct.fromJson(Map<String, dynamic> json) {
    final bq = _asInt(json['batch_qty']);
    return ProductionProduct(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      batchQty: bq < 1 ? 1 : bq,
    );
  }

  // Partiya soni: yuqoriga yaxlitlash — ceil(qty / batchQty).
  int batchesFor(int qty) => qty <= 0 ? 0 : (qty + batchQty - 1) ~/ batchQty;

  static List<ProductionProduct> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ProductionProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Bo'lim masalig'i (snapshot, partiya soniga ko'paytirilgan).
class ProductionIngredient {
  final int productId; // 0 — katalogga bog'lanmagan nom
  final String name;
  final String unit; // g | ml | pcs | m
  final int amount; // jami (barcha partiyalar uchun)
  final String stockUnit; // кг | литр | шт | м (chiqim birligi)
  final double stockAmount; // chiqim uchun o'girilgan qiymat
  final bool linked; // false — sklad qoldig'iga bog'lanmagan (⚠)

  const ProductionIngredient({
    this.productId = 0,
    required this.name,
    this.unit = 'g',
    this.amount = 0,
    this.stockUnit = '',
    this.stockAmount = 0,
    this.linked = false,
  });

  factory ProductionIngredient.fromJson(Map<String, dynamic> json) {
    return ProductionIngredient(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'g',
      amount: _asInt(json['amount']),
      stockUnit: json['stock_unit']?.toString() ?? '',
      stockAmount: _asDouble(json['stock_amount']),
      linked: json['linked'] == true,
    );
  }

  static List<ProductionIngredient> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) =>
              ProductionIngredient.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Masalliq holati qiymatlari (ProductionStage.materialStatus).
abstract final class MaterialStatus {
  static const String none = ''; // hali berilmagan
  static const String berildi = 'berildi';
  static const String qabulQilindi = 'qabul_qilindi';
  static const String radEtildi = 'rad_etildi';
}

// Bitta bo'lim (bosqich) snapshot'i + jarayon holati.
class ProductionStage {
  final String name;
  final List<ProductionIngredient> ingredients;
  final int doneQty; // shef kiritadi (kumulyativ, dona)
  final String materialStatus; // '' | berildi | qabul_qilindi | rad_etildi
  final String issuedAt; // ombor «Berdim» vaqti ('' bo'lishi mumkin)
  final String acceptedAt; // shef qabul/rad vaqti
  final String rejectComment; // rad etilganda izoh

  const ProductionStage({
    required this.name,
    this.ingredients = const [],
    this.doneQty = 0,
    this.materialStatus = '',
    this.issuedAt = '',
    this.acceptedAt = '',
    this.rejectComment = '',
  });

  factory ProductionStage.fromJson(Map<String, dynamic> json) {
    return ProductionStage(
      name: json['name']?.toString() ?? '',
      ingredients: ProductionIngredient.listFromJson(json['ingredients']),
      doneQty: _asInt(json['done_qty']),
      materialStatus: json['material_status']?.toString() ?? '',
      issuedAt: json['issued_at']?.toString() ?? '',
      acceptedAt: json['accepted_at']?.toString() ?? '',
      rejectComment: json['reject_comment']?.toString() ?? '',
    );
  }

  static List<ProductionStage> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ProductionStage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Buyurtmadagi bitta mahsulot qatori (tex karta snapshot'i bilan).
class ProductionItem {
  final int productId;
  final String name;
  final int qty; // buyurtma soni (tayyor bo'lishi kerak bo'lgan)
  final int batchQty; // snapshot
  final int batches; // ceil(qty / batchQty)
  final List<ProductionStage> stages;

  const ProductionItem({
    required this.productId,
    required this.name,
    required this.qty,
    this.batchQty = 1,
    this.batches = 1,
    this.stages = const [],
  });

  factory ProductionItem.fromJson(Map<String, dynamic> json) {
    return ProductionItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      qty: _asInt(json['qty']),
      batchQty: _asInt(json['batch_qty']),
      batches: _asInt(json['batches']),
      stages: ProductionStage.listFromJson(json['stages']),
    );
  }

  // Oxirgi bo'limda tugatilgan soni = to'liq tayyor dona.
  int get doneQty => stages.isEmpty ? 0 : stages.last.doneQty;

  // Qator to'liq tayyormi.
  bool get isReady => qty > 0 && doneQty >= qty;

  static List<ProductionItem> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ProductionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Buyurtma statuslari.
abstract final class ProductionStatus {
  static const String yangi = 'yangi';
  static const String jarayonda = 'jarayonda';
  static const String tayyor = 'tayyor';
}

// Ishlab chiqarish buyurtmasi (P- hisoblagichli).
class ProductionOrder {
  final int id;
  final String orderId; // "P-26-07-09-1"
  final int shefId;
  final String shefName;
  final int skladId;
  final String skladName;
  final String status; // yangi | jarayonda | tayyor
  final String created;
  final String updated;
  final List<ProductionItem> items;

  const ProductionOrder({
    required this.id,
    required this.orderId,
    this.shefId = 0,
    this.shefName = '',
    this.skladId = 0,
    this.skladName = '',
    this.status = ProductionStatus.yangi,
    this.created = '',
    this.updated = '',
    this.items = const [],
  });

  factory ProductionOrder.fromJson(Map<String, dynamic> json) {
    return ProductionOrder(
      id: _asInt(json['id']),
      orderId: json['order_id']?.toString() ?? '',
      shefId: _asInt(json['shef_id']),
      shefName: json['shef_name']?.toString() ?? '',
      skladId: _asInt(json['sklad_id']),
      skladName: json['sklad_name']?.toString() ?? '',
      status: json['status']?.toString() ?? ProductionStatus.yangi,
      created: json['created']?.toString() ?? '',
      updated: json['updated']?.toString() ?? '',
      items: ProductionItem.listFromJson(json['items']),
    );
  }

  // Jami buyurtma soni (hamma qatorlar).
  int get totalQty => items.fold(0, (sum, i) => sum + i.qty);

  // Jami to'liq tayyor dona (har qatorning oxirgi bo'lim done'i).
  int get totalDone => items.fold(0, (sum, i) => sum + i.doneQty);

  // Umumiy progress 0..1 (karta ustidagi % uchun).
  double get progress {
    if (totalQty <= 0) return 0;
    final p = totalDone / totalQty;
    if (p < 0) return 0;
    return p > 1 ? 1 : p;
  }

  static List<ProductionOrder> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ProductionOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
