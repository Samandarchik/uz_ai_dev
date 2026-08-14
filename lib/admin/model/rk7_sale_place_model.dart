// admin/model/rk7_sale_place_model.dart — RK7 sotuv nuqtasi (Rk7SalePlace):
// GET /api/rk7/sale-places va POST /api/rk7/sale-places upsert.
// filial_id/sklad_id = 0 — bog'lanmagan (import satri yechilmaydi).
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart'
    show rk7AsBool, rk7AsInt;

class Rk7SalePlace {
  final int id;
  final String uotGuid;
  final String name; // RK7 dagi nuqta nomi
  final int filialId; // 0 — bog'lanmagan
  final int skladId; // 0 — bog'lanmagan
  final bool active;

  const Rk7SalePlace({
    this.id = 0,
    this.uotGuid = '',
    this.name = '',
    this.filialId = 0,
    this.skladId = 0,
    this.active = true,
  });

  bool get isMapped => filialId > 0 && skladId > 0;

  factory Rk7SalePlace.fromJson(Map<String, dynamic> json) {
    return Rk7SalePlace(
      id: rk7AsInt(json['id']),
      uotGuid: json['uot_guid']?.toString() ?? json['guid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      filialId: rk7AsInt(json['filial_id']),
      skladId: rk7AsInt(json['sklad_id']),
      active: json['active'] == null ? true : rk7AsBool(json['active']),
    );
  }

  /// POST /api/rk7/sale-places tanasi (faqat kontraktdagi maydonlar).
  Map<String, dynamic> toJson() => {
        'uot_guid': uotGuid,
        'filial_id': filialId,
        'sklad_id': skladId,
        'active': active,
      };

  Rk7SalePlace copyWith({int? filialId, int? skladId, bool? active}) {
    return Rk7SalePlace(
      id: id,
      uotGuid: uotGuid,
      name: name,
      filialId: filialId ?? this.filialId,
      skladId: skladId ?? this.skladId,
      active: active ?? this.active,
    );
  }
}
