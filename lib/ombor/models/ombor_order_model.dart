// Ombor o'zi bergan buyurtmalar modeli.
// Backend javobi:
// { "success": true, "message": "...", "data": [ {order}, ... ] }
// Har order:
// { "id":1, "order_id":"26-06-20-1", "sklad_id":1, "sklad_name":"...",
//   "status":"created"|"narxlandi", "total":3000, "created":"...",
//   "items":[ {"product_id":5,"name":"Un","count":3,"type":"kg",
//              "taken":6,"subtotal":3000} ] }

class OmborOrder {
  final int id;
  final String orderId;
  final String skladName;
  final String status; // "created" yoki "narxlandi"
  final double total;
  final String created;
  final List<OmborOrderItem> items;

  OmborOrder({
    required this.id,
    required this.orderId,
    required this.skladName,
    required this.status,
    required this.total,
    required this.created,
    required this.items,
  });

  // Yuk keltiruvchi narx qo'yganmi.
  bool get isPriced => status == 'narxlandi';

  factory OmborOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<OmborOrderItem> parsedItems = (rawItems is List)
        ? rawItems
            .map((e) => OmborOrderItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OmborOrderItem>[];

    return OmborOrder(
      id: json['id'] ?? 0,
      orderId: json['order_id']?.toString() ?? '',
      skladName: json['sklad_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      total: _toDouble(json['total']),
      created: json['created']?.toString() ?? '',
      items: parsedItems,
    );
  }
}

class OmborOrderItem {
  final int productId;
  final String name;
  final double count;
  final String type;
  final double taken;
  final double subtotal;

  OmborOrderItem({
    required this.productId,
    required this.name,
    required this.count,
    required this.type,
    required this.taken,
    required this.subtotal,
  });

  factory OmborOrderItem.fromJson(Map<String, dynamic> json) {
    return OmborOrderItem(
      productId: json['product_id'] ?? 0,
      name: json['name']?.toString() ?? '',
      count: _toDouble(json['count']),
      type: json['type']?.toString() ?? '',
      taken: _toDouble(json['taken']),
      subtotal: _toDouble(json['subtotal']),
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// Javobdagi `data` massivni OmborOrder ro'yxatiga aylantirish.
List<OmborOrder> parseOmborOrders(dynamic data) {
  if (data is List) {
    return data
        .map((e) => OmborOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return <OmborOrder>[];
}
