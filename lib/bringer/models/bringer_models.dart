// ================= BRINGER PROFILE =================

class BringerProfile {
  final int id;
  final String name;
  final String phone;
  final String description;
  final String imageUrl;
  final bool isActive;

  BringerProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.description,
    required this.imageUrl,
    required this.isActive,
  });

  factory BringerProfile.fromJson(Map<String, dynamic> json) {
    return BringerProfile(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'description': description,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'phone': phone,
      'description': description,
      'image_url': imageUrl,
    };
  }

  BringerProfile copyWith({
    int? id,
    String? name,
    String? phone,
    String? description,
    String? imageUrl,
    bool? isActive,
  }) {
    return BringerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}

// ================= BRINGER ORDER =================

class BringerOrder {
  final int id;
  final String orderID;
  final int bringerID;
  final List<BringerOrderItem> items;
  final int total;
  final String status; // active, shipped, delivered
  final String? comment;
  final DateTime created;
  final DateTime updated;

  BringerOrder({
    required this.id,
    required this.orderID,
    required this.bringerID,
    required this.items,
    required this.total,
    required this.status,
    this.comment,
    required this.created,
    required this.updated,
  });

  factory BringerOrder.fromJson(Map<String, dynamic> json) {
    return BringerOrder(
      id: json['id'] ?? 0,
      orderID: json['order_id'] ?? '',
      bringerID: json['bringer_id'] ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => BringerOrderItem.fromJson(e))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      status: json['status'] ?? 'active',
      comment: json['comment'],
      created: json['created'] != null
          ? DateTime.parse(json['created'])
          : DateTime.now(),
      updated: json['updated'] != null
          ? DateTime.parse(json['updated'])
          : DateTime.now(),
    );
  }
}

class BringerOrderItem {
  final int id;
  final int productID;
  final String name;
  final double count;
  final int price;
  final int subtotal;
  final String type;
  final String? videoUrl;
  final String? comment;
  final String imageUrl;
  final DateTime created;

  BringerOrderItem({
    required this.id,
    required this.productID,
    required this.name,
    required this.count,
    required this.price,
    required this.subtotal,
    required this.type,
    this.videoUrl,
    this.comment,
    required this.imageUrl,
    required this.created,
  });

  factory BringerOrderItem.fromJson(Map<String, dynamic> json) {
    return BringerOrderItem(
      id: json['id'] ?? 0,
      productID: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      count: (json['count'] ?? 0).toDouble(),
      price: json['price'] ?? 0,
      subtotal: json['subtotal'] ?? 0,
      type: json['type'] ?? '',
      videoUrl: json['video_url'],
      comment: json['comment'],
      imageUrl: json['image_url'] ?? '',
      created: json['created'] != null
          ? DateTime.parse(json['created'])
          : DateTime.now(),
    );
  }
}

// ================= BRINGER BALANCE =================

class BringerBalance {
  final int bringerID;
  final int totalBalance;
  final int spentBalance;
  final int availableBalance;

  BringerBalance({
    required this.bringerID,
    required this.totalBalance,
    required this.spentBalance,
    required this.availableBalance,
  });

  factory BringerBalance.fromJson(Map<String, dynamic> json) {
    return BringerBalance(
      bringerID: json['bringer_id'] ?? 0,
      totalBalance: json['total_balance'] ?? 0,
      spentBalance: json['spent_balance'] ?? 0,
      availableBalance: json['available_balance'] ?? 0,
    );
  }
}

class BringerTransaction {
  final int id;
  final int bringerID;
  final int amount;
  final String type; // credit (kirim), debit (chiqim)
  final String? comment;
  final DateTime created;

  BringerTransaction({
    required this.id,
    required this.bringerID,
    required this.amount,
    required this.type,
    this.comment,
    required this.created,
  });

  factory BringerTransaction.fromJson(Map<String, dynamic> json) {
    return BringerTransaction(
      id: json['id'] ?? 0,
      bringerID: json['bringer_id'] ?? 0,
      amount: json['amount'] ?? 0,
      type: json['type'] ?? '',
      comment: json['comment'],
      created: json['created'] != null
          ? DateTime.parse(json['created'])
          : DateTime.now(),
    );
  }
}

// ================= BRINGER TASK =================

class BringerTaskItem {
  final int productID;
  final String name;
  final String type;
  final String imageUrl;
  final double requiredCount;
  final double purchasedCount;
  final double remainingCount;

  BringerTaskItem({
    required this.productID,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.requiredCount,
    required this.purchasedCount,
    required this.remainingCount,
  });

  factory BringerTaskItem.fromJson(Map<String, dynamic> json) {
    return BringerTaskItem(
      productID: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      imageUrl: json['image_url'] ?? '',
      requiredCount: (json['required_count'] ?? 0).toDouble(),
      purchasedCount: (json['purchased_count'] ?? 0).toDouble(),
      remainingCount: (json['remaining_count'] ?? 0).toDouble(),
    );
  }
}
