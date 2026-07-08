// Tortlar «tex karta» (тех карта) modeli.
// Barcha OG'IRLIK/HAJM butun son (int) — eng kichik birlikda: g yoki ml.
// Dona (pcs) va metr (m) o'z birligida butun son. float ISHLATILMAYDI.
// amount — PARTIYA uchun (batch_qty dona). 1 dona uchun = amount / batch_qty.
// Backend JSON snake_case.

// Ruxsat etilgan birliklar (faqat shular).
const List<String> kTechUnits = ['g', 'ml', 'pcs', 'm'];

// Birlikni ko'rsatish uchun ruscha yorliq (qiymat o'zgarmaydi).
String techUnitLabel(String unit) {
  switch (unit) {
    case 'g':
      return 'г';
    case 'ml':
      return 'мл';
    case 'pcs':
      return 'дона';
    case 'm':
      return 'м';
    default:
      return unit;
  }
}

// Noma'lum/eski birlikni ruxsat etilgan birlikka moslaydi.
String normalizeTechUnit(String? unit) {
  final u = (unit ?? '').toLowerCase().trim();
  if (kTechUnits.contains(u)) return u;
  switch (u) {
    case 'г':
    case 'гр':
    case 'грамм':
    case 'кг':
      return 'g';
    case 'мл':
    case 'л':
      return 'ml';
    case 'шт':
    case 'шт.':
    case 'дона':
    case 'pc':
      return 'pcs';
    case 'м':
    case 'см':
    case 'метр':
      return 'm';
    default:
      return 'g';
  }
}

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

// Bitta ingredient/расходник (item).
class TechItem {
  final int productId;
  final String name;
  final String unit; // g | ml | pcs | m
  final int amount; // partiya uchun miqdor
  // Switch YONIQ bo'lsa shu nom «Состав»ga chiqadi.
  final bool showInSostav;

  const TechItem({
    this.productId = 0,
    required this.name,
    required this.unit,
    required this.amount,
    this.showInSostav = false,
  });

  factory TechItem.fromJson(Map<String, dynamic> json) {
    final rawShow = json['show_in_sostav'];
    return TechItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      unit: normalizeTechUnit(json['unit']?.toString()),
      amount: _asInt(json['amount']),
      showInSostav: rawShow == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'unit': unit,
        'amount': amount,
        'show_in_sostav': showInSostav,
      };

  TechItem copyWith({
    int? productId,
    String? name,
    String? unit,
    int? amount,
    bool? showInSostav,
  }) {
    return TechItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      amount: amount ?? this.amount,
      showInSostav: showInSostav ?? this.showInSostav,
    );
  }

  static List<TechItem> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => TechItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Ishlab chiqarish bo'limi (bosqichi): Бисквит, Крем, Безаш...
// Tartibi = ishlab chiqarish tartibi. Har baza bitta bo'limga biriktiriladi.
class TechStage {
  final String name;

  const TechStage({required this.name});

  factory TechStage.fromJson(Map<String, dynamic> json) {
    return TechStage(name: json['name']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'name': name};

  static List<TechStage> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => TechStage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Yarim tayyor blok (biskvit, krem, sироп, ...).
class TechBase {
  final String name;
  final int weightG; // server avto hisoblaydi
  final List<TechItem> ingredients;

  // Excel'dagi blok sarlavhasi rangi: "#RRGGBB" yoki '' (standart kulrang).
  final String color;

  // Blok rasmi: "/static/<fayl>" yoki '' (rasm yo'q). JSON kaliti: image_url.
  final String imageUrl;

  // Nechanchi bo'limga (TechCard.stages, 1-based) tegishli.
  // 0 yoki noto'g'ri qiymat = 1-bo'lim deb olinadi.
  final int stage;

  const TechBase({
    required this.name,
    this.weightG = 0,
    this.ingredients = const [],
    this.color = '',
    this.imageUrl = '',
    this.stage = 1,
  });

  factory TechBase.fromJson(Map<String, dynamic> json) {
    final rawStage = _asInt(json['stage']);
    return TechBase(
      name: json['name']?.toString() ?? '',
      weightG: _asInt(json['weight_g']),
      ingredients: TechItem.listFromJson(json['ingredients']),
      color: json['color']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      stage: rawStage < 1 ? 1 : rawStage,
    );
  }

  // Mahalliy hisoblangan og'irlik: faqat g/ml ingredientlar yig'indisi.
  int get computedWeightG => ingredients
      .where((i) => i.unit == 'g' || i.unit == 'ml')
      .fold(0, (sum, i) => sum + i.amount);

  Map<String, dynamic> toJson() => {
        'name': name,
        // Saqlashda mahalliy hisoblangan qiymatni yuboramiz (server qayta hisoblaydi).
        'weight_g': computedWeightG,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'color': color,
        'image_url': imageUrl,
        'stage': stage < 1 ? 1 : stage,
      };

  TechBase copyWith({
    String? name,
    int? weightG,
    List<TechItem>? ingredients,
    String? color,
    String? imageUrl,
    int? stage,
  }) {
    return TechBase(
      name: name ?? this.name,
      weightG: weightG ?? this.weightG,
      ingredients: ingredients ?? this.ingredients,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      stage: stage ?? this.stage,
    );
  }

  static List<TechBase> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => TechBase.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// To'liq tex karta.
class TechCard {
  final int batchQty; // partiyada nechta dona
  final int batchWeightG; // server avto hisoblaydi
  final int pieceWeightG; // server avto hisoblaydi
  final int? diameterCm; // tort uchun ixtiyoriy
  // Bo'limlar (bosqichlar) ro'yxati; bo'sh bo'lsa hammasi 1 ta bo'lim deb olinadi.
  final List<TechStage> stages;
  final List<TechBase> bases;
  final List<TechItem> consumables; // qadoqlash materiallari

  const TechCard({
    this.batchQty = 1,
    this.batchWeightG = 0,
    this.pieceWeightG = 0,
    this.diameterCm,
    this.stages = const [],
    this.bases = const [],
    this.consumables = const [],
  });

  factory TechCard.fromJson(Map<String, dynamic> json) {
    return TechCard(
      batchQty: json['batch_qty'] == null ? 1 : _asInt(json['batch_qty']),
      batchWeightG: _asInt(json['batch_weight_g']),
      pieceWeightG: _asInt(json['piece_weight_g']),
      diameterCm:
          json['diameter_cm'] == null ? null : _asInt(json['diameter_cm']),
      stages: TechStage.listFromJson(json['stages']),
      bases: TechBase.listFromJson(json['bases']),
      consumables: TechItem.listFromJson(json['consumables']),
    );
  }

  // Mahalliy hisoblangan partiya og'irligi (bazalar yig'indisi).
  int get computedBatchWeightG =>
      bases.fold(0, (sum, b) => sum + b.computedWeightG);

  // Mahalliy hisoblangan 1 dona og'irligi.
  int get computedPieceWeightG =>
      batchQty > 0 ? computedBatchWeightG ~/ batchQty : 0;

  Map<String, dynamic> toJson() => {
        'batch_qty': batchQty,
        // Mahalliy hisoblangan qiymatlar (server qayta hisoblaydi).
        'batch_weight_g': computedBatchWeightG,
        'piece_weight_g': computedPieceWeightG,
        'diameter_cm': diameterCm,
        'stages': stages.map((e) => e.toJson()).toList(),
        'bases': bases.map((e) => e.toJson()).toList(),
        'consumables': consumables.map((e) => e.toJson()).toList(),
      };

  TechCard copyWith({
    int? batchQty,
    int? batchWeightG,
    int? pieceWeightG,
    int? diameterCm,
    bool clearDiameter = false,
    List<TechStage>? stages,
    List<TechBase>? bases,
    List<TechItem>? consumables,
  }) {
    return TechCard(
      batchQty: batchQty ?? this.batchQty,
      batchWeightG: batchWeightG ?? this.batchWeightG,
      pieceWeightG: pieceWeightG ?? this.pieceWeightG,
      diameterCm: clearDiameter ? null : (diameterCm ?? this.diameterCm),
      stages: stages ?? this.stages,
      bases: bases ?? this.bases,
      consumables: consumables ?? this.consumables,
    );
  }

  // «Состав» uchun showInSostav=true bo'lgan barcha nomlar (bazalar + расходник).
  List<String> sostavNames() {
    final names = <String>[];
    for (final base in bases) {
      for (final item in base.ingredients) {
        if (item.showInSostav) names.add(item.name);
      }
    }
    for (final item in consumables) {
      if (item.showInSostav) names.add(item.name);
    }
    return names;
  }
}
