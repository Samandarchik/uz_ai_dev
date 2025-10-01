// models/order_model.dart
class Order {
  final int? id;
  final String? orderId;
  final String? username;
  final String? filialName;
  final String? status;
  final DateTime? created;
  final List<OrderItemDetail>? items;

  Order({
    this.id,
    this.orderId,
    this.username,
    this.filialName,
    this.status,
    this.created,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderId: json['order_id']?.toString(),
      username: json['username'],
      filialName: json['filial_name'],
      status: json['status'],
      created: json['created'] != null ? DateTime.parse(json['created']) : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => OrderItemDetail.fromJson(item))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'username': username,
      'filial_name': filialName,
      'status': status,
      'created': created?.toIso8601String(),
      'items': items?.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderItemDetail {
  final int? productId;
  final String? productName;
  final int? count;

  OrderItemDetail({
    this.productId,
    this.productName,
    this.count,
  });

  factory OrderItemDetail.fromJson(Map<String, dynamic> json) {
    return OrderItemDetail(
      productId: json['product_id'],
      productName: json['product_name'],
      count: json['count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'count': count,
    };
  }
}

class CreateOrderRequest {
  final String username;
  final String filial;
  final List<OrderItem> items;

  CreateOrderRequest({
    required this.username,
    required this.filial,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'filial': filial,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderItem {
  final int productId;
  final int count;

  OrderItem({
    required this.productId,
    required this.count,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'count': count,
    };
  }
}
