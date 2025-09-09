// models/user_model.dart
class User {
  final int? id;
  final String? name;
  final String? phone;
  final Filial? filial;

  User({
    this.id,
    this.name,
    this.phone,
    this.filial,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      filial: json['filial'] != null ? Filial.fromJson(json['filial']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'filial': filial?.toJson(),
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