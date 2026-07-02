class User {
  final int id;
  final String name;
  final String phone;
  final bool isAdmin;
  final String role; // superadmin, admin, seller, ombor, yuk_keltiruvchi
  final int? filialId;
  final Filial? filial;
  final String? password;
  final List<int>? categoryIds;
  final List<int> sklads;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.isAdmin,
    this.role = 'seller',
    this.filialId,
    this.filial,
    this.password,
    this.categoryIds,
    this.sklads = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      isAdmin: json['is_admin'] ?? false,
      role: json['role'] ?? 'seller',
      filialId: json['filial_id'],
      filial: json['filial'] != null ? Filial.fromJson(json['filial']) : null,
      categoryIds: (json['category_list'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      sklads: (json['sklads'] as List?)?.map((e) => e as int).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'is_admin': isAdmin,
      'role': role,
      'filial_id': filialId,
      'sklads': sklads,
      if (password != null) 'password': password,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? phone,
    bool? isAdmin,
    String? role,
    int? filialId,
    Filial? filial,
    String? password,
    List<int>? sklads,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
      filialId: filialId ?? this.filialId,
      filial: filial ?? this.filial,
      password: password ?? this.password,
      sklads: sklads ?? this.sklads,
    );
  }
}
// ================ MODELS ================
// models/user_models.dart

class Filial {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String? location;

  Filial({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.location,
  });

  factory Filial.fromJson(Map<String, dynamic> json) {
    return Filial(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'location': location,
    };
  }
}

class UpdateUserRequest {
  final String? name;
  final String? phone;
  final bool? isAdmin;
  final String? role;
  final int? filialId;
  final String? password;
  final List<int>? categoryIds;
  final List<int>? sklads;

  UpdateUserRequest({
    this.name,
    this.phone,
    this.isAdmin,
    this.role,
    this.filialId,
    this.password,
    this.categoryIds,
    this.sklads,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (isAdmin != null) data['is_admin'] = isAdmin;
    if (role != null) data['role'] = role;
    if (filialId != null) data['filial_id'] = filialId;
    if (password != null && password!.isNotEmpty) data['password'] = password;
    if (categoryIds != null) data['category_list'] = categoryIds;
    if (sklads != null) data['sklads'] = sklads;
    return data;
  }
}

class CreateUserRequest {
  final String name;
  final String phone;
  final String password;
  final bool isAdmin;
  final String role;
  final int? filialId;
  final List<int>? categoryIds;
  final List<int> sklads;

  CreateUserRequest({
    required this.name,
    required this.phone,
    required this.password,
    this.isAdmin = false,
    this.role = 'seller',
    this.filialId,
    this.categoryIds,
    this.sklads = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'is_admin': isAdmin,
      'role': role,
      if (filialId != null) 'filial_id': filialId,
      'category_list': categoryIds,
      'sklads': sklads,
    };
  }
}
