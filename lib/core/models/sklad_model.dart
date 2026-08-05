// core/models/sklad_model.dart — sklad (omborxona) modeli: backend
// `GET/POST/PUT /api/sklads` javobidagi {id, name}. Nomlarni butun ilova
// SkladRegistry orqali o'qiydi (core/data/sklad_registry.dart).

class Sklad {
  final int id;
  final String name;

  const Sklad({required this.id, required this.name});

  factory Sklad.fromJson(Map<String, dynamic> json) => Sklad(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
