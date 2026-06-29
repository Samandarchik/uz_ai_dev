// Yuk keltiruvchi roli uchun sklad buyurtmasi modeli.
// Backend javobi:
// { "success": true, "message": "...", "data": [ {order}, ... ] }
// Har bir order:
// { "id":1, "order_id":"26-06-20-1", "username":"Ombor Test",
//   "sklad_id":1, "sklad_name":"Marxabo Sklat",
//   "items":[{"product_id":5,"name":"Un","count":3,"type":"kg"}],
//   "total":0, "status":"created", "created":"2026-06-20T..." }

class YukOrderItem {
  final int productId;
  final String name;
  final num count;
  final String? type;
  // Narxlangan buyurtmada: olingan miqdor va shu item jami summasi.
  final double taken;
  final double subtotal;

  YukOrderItem({
    required this.productId,
    required this.name,
    required this.count,
    this.type,
    this.taken = 0,
    this.subtotal = 0,
  });

  factory YukOrderItem.fromJson(Map<String, dynamic> json) {
    return YukOrderItem(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      type: json['type'],
      taken: (json['taken'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  // Offline kesh uchun (fromJson bilan teskari).
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'count': count,
        'type': type,
        'taken': taken,
        'subtotal': subtotal,
      };
}

class YukOrder {
  final int id;
  final String orderId;
  final String username;
  final int skladId;
  final String skladName;
  final num total;
  final String status;
  final String created;
  final List<YukOrderItem> items;

  YukOrder({
    required this.id,
    required this.orderId,
    required this.username,
    required this.skladId,
    required this.skladName,
    required this.total,
    required this.status,
    required this.created,
    required this.items,
  });

  factory YukOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <YukOrderItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(YukOrderItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return YukOrder(
      id: json['id'] ?? 0,
      orderId: json['order_id']?.toString() ?? '',
      username: json['username'] ?? '',
      skladId: json['sklad_id'] ?? 0,
      skladName: json['sklad_name'] ?? '',
      total: json['total'] ?? 0,
      status: json['status'] ?? '',
      created: json['created']?.toString() ?? '',
      items: items,
    );
  }

  // Offline kesh uchun (fromJson bilan teskari).
  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'username': username,
        'sklad_id': skladId,
        'sklad_name': skladName,
        'total': total,
        'status': status,
        'created': created,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

// Javobdagi `data` massivini parse qilish.
List<YukOrder> parseYukOrders(dynamic data) {
  final result = <YukOrder>[];
  if (data is List) {
    for (final item in data) {
      if (item is Map) {
        result.add(YukOrder.fromJson(Map<String, dynamic>.from(item)));
      }
    }
  }
  return result;
}
