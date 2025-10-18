class User {
  final int id;
  final String name;
  final String phone;
  final bool isAdmin;
  final String? password;
  final String location;
  final double long;
  final double lat;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.isAdmin,
    required this.location,
    required this.long,
    required this.lat,
    this.password,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      isAdmin: json['is_admin'] ?? false,
      location: json['location'] ?? '',
      long: json['long'] ?? 0.0,
      lat: json['lat'] ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'is_admin': isAdmin,
      if (password != null) 'password': password,
      'location': location,
      'long': long,
      'lat': lat
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
      location: location,
      long: long,
      lat: lat,
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
  final String? password;
  final double? long;
  final double? lat;
  final String? location;

  UpdateUserRequest({
    this.name,
    this.phone,
    this.isAdmin,
    this.location,
    this.long,
    this.lat,
    this.password,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (isAdmin != null) data['is_admin'] = isAdmin;
    if (location != null) data['location'] = location;
    if (password != null && password!.isNotEmpty) data['password'] = password;
    if (long != null) data['long'] = long;
    if (lat != null) data['lat'] = lat;
    return data;
  }
}

class CreateUserRequest {
  final String name;
  final String phone;
  final String password;
  final bool isAdmin;
  final double long;
  final double lat;
  final String location;

  CreateUserRequest({
    required this.name,
    required this.phone,
    required this.password,
    this.isAdmin = false,
    required this.long,
    required this.lat,
    required this.location,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'is_admin': isAdmin,
      'location': location,
      'long': long,
      'lat': lat
    };
  }
}
