// user/models/product_model.dart — Seller buyurtma item modeli: OrderItem (productId, count, type).
class OrderItem {
  final int productId;
  final int count;
  final String? type;
  OrderItem({required this.productId, required this.count, this.type});

  Map<String, dynamic> toJson() {
    return {'product_id': productId, 'count': count, 'type': type};
  }
}
