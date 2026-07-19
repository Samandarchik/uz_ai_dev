// POS (Konak) buyurtmalari — «POS avto» useri yaratgan avto-buyurtmalar va
// ularning bazadan yuborilishi (PosDelivery).
// Kontrakt: GET /api/pos-orders?limit=50 (faqat admin),
//           POST /api/pos-orders/{id}/dispatch — javob data = PosDelivery.
//
// MUHIM (gram kontrakt): miqdorlar (count / sent_qty / accepted_qty) API'da
// saqlanadigan birlikdagi BUTUN son — кг/л mahsulotlarda gr/ml. UI'ga
// chiqarishda formatQtyUnit bilan qaytariladi. Pul (subtotal/total) — butun
// so'm (tiyin yo'q).

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

DateTime? _asDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

// Yuborilgan mahsulot qatori. accepted_qty null — POS hali qabul qilmagan.
class PosDeliveryItem {
  final int productId;
  final String name;
  final String unit;
  final int sentQty;
  final int? acceptedQty;
  final DateTime? acceptedAt;

  const PosDeliveryItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.sentQty,
    this.acceptedQty,
    this.acceptedAt,
  });

  // Kamomad: qabul qilingan, lekin yuborilganidan kam.
  bool get isShortfall => acceptedQty != null && acceptedQty! < sentQty;

  factory PosDeliveryItem.fromJson(Map<String, dynamic> json) {
    return PosDeliveryItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      sentQty: _asInt(json['sent_qty']),
      acceptedQty:
          json['accepted_qty'] == null ? null : _asInt(json['accepted_qty']),
      acceptedAt: _asDate(json['accepted_at']),
    );
  }
}

// Bazadan POS'ga yuborish yozuvi. status: "sent" | "completed".
class PosDelivery {
  final int id;
  final int orderId; // ichki Order.ID
  final String orderCode; // masalan "26-07-18-1"
  final int filialId;
  final String filialName;
  final String status;
  final DateTime? created;
  final DateTime? updated;
  final List<PosDeliveryItem> items;

  const PosDelivery({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.filialId,
    required this.filialName,
    required this.status,
    this.created,
    this.updated,
    this.items = const [],
  });

  factory PosDelivery.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PosDelivery(
      id: _asInt(json['id']),
      orderId: _asInt(json['order_id']),
      orderCode: json['order_code']?.toString() ?? '',
      filialId: _asInt(json['filial_id']),
      filialName: json['filial_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      created: _asDate(json['created']),
      updated: _asDate(json['updated']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) =>
                  PosDeliveryItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

// Buyurtma ichidagi mahsulot qatori (faqat o'chirilmagan itemlar keladi).
class PosOrderItem {
  final int productId;
  final String name;
  final String unit;
  final int count; // saqlanadigan birlikda butun
  final int subtotal; // butun so'm

  const PosOrderItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.count,
    required this.subtotal,
  });

  factory PosOrderItem.fromJson(Map<String, dynamic> json) {
    return PosOrderItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      count: _asInt(json['count']),
      subtotal: _asInt(json['subtotal']),
    );
  }
}

// «POS avto» buyurtmasi. delivery — shu buyurtma uchun yaratilgan
// pos_delivery (bo'lmasa null = hali yuborilmagan). Dispatch'dan keyin
// joyida yangilanadi (to'liq re-fetch YO'Q), shuning uchun final emas.
class PosOrder {
  final int id;
  final String orderId; // buyurtma kodi, masalan "26-07-18-1"
  final int filialId;
  final String filialName;
  final String status;
  final DateTime? created;
  final int total; // butun so'm
  final List<PosOrderItem> items;
  PosDelivery? delivery;

  PosOrder({
    required this.id,
    required this.orderId,
    required this.filialId,
    required this.filialName,
    required this.status,
    this.created,
    this.total = 0,
    this.items = const [],
    this.delivery,
  });

  factory PosOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawDelivery = json['delivery'];
    return PosOrder(
      id: _asInt(json['id']),
      orderId: json['order_id']?.toString() ?? '',
      filialId: _asInt(json['filial_id']),
      filialName: json['filial_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      created: _asDate(json['created']),
      total: _asInt(json['total']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => PosOrderItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      delivery: rawDelivery is Map
          ? PosDelivery.fromJson(Map<String, dynamic>.from(rawDelivery))
          : null,
    );
  }
}
