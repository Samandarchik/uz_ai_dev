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
  // Omborchi qabul qilganda kiritgan haqiqatda kelgan miqdor (taken'dan kam
  // bo'lsa kamomad). Qabul qilinmaguncha 0.
  final double received;
  // Item turi: '' — oddiy buyurtma mahsuloti, 'proche' — yuk keltiruvchi
  // qo'shgan qo'shimcha mahsulot, 'rasxod' — xarajat/xizmat (ombor qabul
  // qilmaydi, chek oxirida alohida ko'rsatiladi).
  final String itemType;

  YukOrderItem({
    required this.productId,
    required this.name,
    required this.count,
    this.type,
    this.taken = 0,
    this.subtotal = 0,
    this.received = 0,
    this.itemType = '',
  });

  bool get isRasxod => itemType == 'rasxod';
  bool get isProche => itemType == 'proche';

  factory YukOrderItem.fromJson(Map<String, dynamic> json) {
    return YukOrderItem(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      type: json['type'],
      taken: (json['taken'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      received: (json['received'] ?? 0).toDouble(),
      itemType: json['item_type']?.toString() ?? '',
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
        'received': received,
        'item_type': itemType,
      };
}

// Yuk keltiruvchi buyurtmaga o'zi qo'shgan qo'shimcha yozuv (hali yuborilmagan,
// lokal saqlanadi): 'proche' — qo'shimcha mahsulot (nomi + soni + jami summa),
// 'rasxod' — xarajat/xizmat (nomi + jami summa, soni 0).
class YukAddedItem {
  final String itemType; // 'proche' | 'rasxod'
  final String name;
  final double taken;
  final double subtotal;

  YukAddedItem({
    required this.itemType,
    required this.name,
    required this.taken,
    required this.subtotal,
  });

  bool get isRasxod => itemType == 'rasxod';
  bool get isProche => itemType == 'proche';

  factory YukAddedItem.fromJson(Map<String, dynamic> json) {
    return YukAddedItem(
      itemType: json['item_type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      taken: (json['taken'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        'name': name,
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
  // Rasxod (xarajat) itemlar yig'indisi. total rasxodni O'Z ICHIGA OLMAYDI;
  // umumiy chek = total + expensesTotal.
  final double expensesTotal;
  // Ombor qabul qilgandan keyin kamaygan jami summa. total — narxlangan
  // to'liq summa bo'lib qoladi. receivedTotal != total (va >0) bo'lsa —
  // kam qabul qilingan.
  final double receivedTotal;
  final String status;
  final String created;
  final List<YukOrderItem> items;
  // Yuk keltiruvchi narxlashda biriktirgan rasm/video URL'lari
  // (relativ /static/yuk/...). Ko'rsatishda AppUrls.baseUrl qo'shiladi.
  final List<String> attachments;

  YukOrder({
    required this.id,
    required this.orderId,
    required this.username,
    required this.skladId,
    required this.skladName,
    required this.total,
    this.expensesTotal = 0,
    this.receivedTotal = 0,
    required this.status,
    required this.created,
    required this.items,
    this.attachments = const [],
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

    final rawAttachments = json['attachments'];
    final attachments = <String>[];
    if (rawAttachments is List) {
      for (final a in rawAttachments) {
        if (a != null && a.toString().isNotEmpty) {
          attachments.add(a.toString());
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
      expensesTotal: (json['expenses_total'] ?? 0).toDouble(),
      receivedTotal: (json['received_total'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      created: json['created']?.toString() ?? '',
      items: items,
      attachments: attachments,
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
        'expenses_total': expensesTotal,
        'received_total': receivedTotal,
        'status': status,
        'created': created,
        'items': items.map((e) => e.toJson()).toList(),
        'attachments': attachments,
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
