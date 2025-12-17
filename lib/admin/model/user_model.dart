class User {
  final int id;
  final String name;
  final String phone;
  final bool isAdmin;
  final int? filialId;
  final Filial? filial;
  final String? password;
  final List<int>? categoryIds;

  User(
      {required this.id,
      required this.name,
      required this.phone,
      required this.isAdmin,
      this.filialId,
      this.filial,
      this.password,
      this.categoryIds});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      isAdmin: json['is_admin'] ?? false,
      filialId: json['filial_id'],
      filial: json['filial'] != null ? Filial.fromJson(json['filial']) : null,
      categoryIds: (json['category_list'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'is_admin': isAdmin,
      'filial_id': filialId,
      if (password != null) 'password': password,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? phone,
    bool? isAdmin,
    int? filialId,
    Filial? filial,
    String? password,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isAdmin: isAdmin ?? this.isAdmin,
      filialId: filialId ?? this.filialId,
      filial: filial ?? this.filial,
      password: password ?? this.password,
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
  final int? filialId;
  final String? password;
  final List<int>? categoryIds;

  UpdateUserRequest({
    this.name,
    this.phone,
    this.isAdmin,
    this.filialId,
    this.password,
    this.categoryIds,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (isAdmin != null) data['is_admin'] = isAdmin;
    if (filialId != null) data['filial_id'] = filialId;
    if (password != null && password!.isNotEmpty) data['password'] = password;
    if (categoryIds != null) data['category_list'] = categoryIds;
    return data;
  }
}

class CreateUserRequest {
  final String name;
  final String phone;
  final String password;
  final bool isAdmin;
  final int? filialId;
  final List<int>? categoryIds;

  CreateUserRequest({
    required this.name,
    required this.phone,
    required this.password,
    this.isAdmin = false,
    this.filialId,
    this.categoryIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'is_admin': isAdmin,
      if (filialId != null) 'filial_id': filialId,
      'category_list': categoryIds
    };
  }
}

class AssignFilialRequest {
  final int filialId;

  AssignFilialRequest({required this.filialId});

  Map<String, dynamic> toJson() {
    return {
      'filial_id': filialId,
    };
  }
}
