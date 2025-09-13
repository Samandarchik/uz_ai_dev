// models/user_model.dart
class User {
  final int? id;
  final String? name;
  final bool? isAdmin;
  final String? phone;
  final Filial? filial;

  User({
    this.id,
    this.name,
    this.phone,
    this.filial,
    this.isAdmin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      filial: json['filial'] != null ? Filial.fromJson(json['filial']) : null,
      isAdmin: json['is_admin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'filial': filial?.toJson(),
      'is_admin': isAdmin,
    };
  }
}

class Filial {
  final int? id;
  final String? name;

  Filial({
    this.id,
    this.name,
  });

  factory Filial.fromJson(Map<String, dynamic> json) {
    return Filial(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}