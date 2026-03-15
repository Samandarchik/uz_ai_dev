// ================= CUSTOMER ORDER =================

class CustomerOrder {
  final int id;
  final String orderID;
  final int customerID;
  final List<CustomerOrderItem> items;
  final String status; // ordered, purchased, shipped, delivered
  final String? comment;
  final DateTime created;
  final DateTime updated;

  CustomerOrder({
    required this.id,
    required this.orderID,
    required this.customerID,
    required this.items,
    required this.status,
    this.comment,
    required this.created,
    required this.updated,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: json['id'] ?? 0,
      orderID: json['order_id'] ?? '',
      customerID: json['customer_id'] ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CustomerOrderItem.fromJson(e))
              .toList() ??
          [],
      status: json['status'] ?? 'ordered',
      comment: json['comment'],
      created: json['created'] != null
          ? DateTime.parse(json['created'])
          : DateTime.now(),
      updated: json['updated'] != null
          ? DateTime.parse(json['updated'])
          : DateTime.now(),
    );
  }

  String get statusText {
    switch (status) {
      case 'ordered':
        return 'Buyurtma qilingan';
      case 'purchased':
        return 'Sotib olingan';
      case 'shipped':
        return 'Yetkazilmoqda';
      case 'delivered':
        return 'Yetkazildi';
      default:
        return status;
    }
  }
}

class CustomerOrderItem {
  final int productID;
  final String name;
  final double count;
  final String type;
  final int bringerID;
  final String imageUrl;

  CustomerOrderItem({
    required this.productID,
    required this.name,
    required this.count,
    required this.type,
    required this.bringerID,
    required this.imageUrl,
  });

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) {
    return CustomerOrderItem(
      productID: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      count: (json['count'] ?? 0).toDouble(),
      type: json['type'] ?? '',
      bringerID: json['bringer_id'] ?? 0,
      imageUrl: json['image_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productID,
      'count': count,
    };
  }
}
