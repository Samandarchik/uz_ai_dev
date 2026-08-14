// admin/model/rk7_mapping_model.dart — RK7 taomi → Mone mahsuloti bog'lanishi
// (Rk7Mapping): GET /api/rk7/mappings?q= va POST /api/rk7/mappings upsert.
//
// MUHIM: `per_portion` — BUTUN son (1 porsiyaga necha SAQLASH birligi: шт→1,
// кг mahsulotga gramm). Serverga float YUBORILMAYDI.
//
// `sklad_id` — IXTIYORIY sklad override (PLAN_RK7 §9.4): 0 = sotuv nuqtasining
// skladi (default), ≠0 = shu mahsulot aynan tanlangan skladdan yechiladi.
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart'
    show rk7AsBool, rk7AsInt;

/// Yechish rejimi: tayyor mahsulotning o'zi yechiladi yoki tex kartadagi
/// ingredientlar yechiladi.
class Rk7DeductMode {
  static const String self = 'self';
  static const String ingredients = 'ingredients';
}

class Rk7Mapping {
  final int id;
  final String dishGuid;
  final String dishCode; // rk7_dishes bilan JOIN natijasi
  final String dishName;
  final int productId; // 0 — bog'lanmagan
  final String productName; // backend qaytarsa ko'rsatiladi
  final String deductMode; // "self" | "ingredients"
  final int perPortion; // BUTUN, default 1
  final int skladId; // 0 — nuqtaning skladi (default), aks holda override
  final bool active;

  const Rk7Mapping({
    this.id = 0,
    this.dishGuid = '',
    this.dishCode = '',
    this.dishName = '',
    this.productId = 0,
    this.productName = '',
    this.deductMode = Rk7DeductMode.self,
    this.perPortion = 1,
    this.skladId = 0,
    this.active = true,
  });

  bool get isMapped => productId > 0;

  /// `sklad_id != 0` — yechish nuqta skladi o'rniga shu skladdan bo'ladi.
  bool get hasSkladOverride => skladId > 0;

  factory Rk7Mapping.fromJson(Map<String, dynamic> json) {
    final mode = json['deduct_mode']?.toString() ?? '';
    return Rk7Mapping(
      id: rk7AsInt(json['id']),
      dishGuid: json['dish_guid']?.toString() ?? '',
      dishCode: json['code']?.toString() ?? json['dish_code']?.toString() ?? '',
      dishName:
          json['name']?.toString() ?? json['dish_name']?.toString() ?? '',
      productId: rk7AsInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      deductMode:
          mode == Rk7DeductMode.ingredients ? mode : Rk7DeductMode.self,
      perPortion:
          json['per_portion'] == null ? 1 : rk7AsInt(json['per_portion']),
      skladId: rk7AsInt(json['sklad_id']),
      active: json['active'] == null ? true : rk7AsBool(json['active']),
    );
  }

  /// POST /api/rk7/mappings tanasi (faqat kontraktdagi maydonlar).
  Map<String, dynamic> toJson() => {
        'dish_guid': dishGuid,
        'product_id': productId,
        'deduct_mode': deductMode,
        'per_portion': perPortion,
        'sklad_id': skladId,
        'active': active,
      };

  Rk7Mapping copyWith({
    int? productId,
    String? productName,
    String? deductMode,
    int? perPortion,
    int? skladId,
    bool? active,
  }) {
    return Rk7Mapping(
      id: id,
      dishGuid: dishGuid,
      dishCode: dishCode,
      dishName: dishName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      deductMode: deductMode ?? this.deductMode,
      perPortion: perPortion ?? this.perPortion,
      skladId: skladId ?? this.skladId,
      active: active ?? this.active,
    );
  }
}
