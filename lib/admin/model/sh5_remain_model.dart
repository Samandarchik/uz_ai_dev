// admin/model/sh5_remain_model.dart — SH5 (StoreHouse) qoldiq modellari
// (Sh5RemainSklad, Sh5RemainGood). PLAN_OSTATKA bosqich 0: manba vaqtincha
// StoreHouse — bridge push qiladi, ilova faqat KO'RADI.
//
// Kontrakt: GET /api/sh5/remains — {sklads:[{id, sh5_rid, name, taken_at,
// goods_count}]}; GET /api/sh5/remains/{id}?q= — {name, taken_at, goods:[...]}.
//
// MUHIM (son kontrakti): `qty_milli` — qoldiq × 1000, BUTUN son (SH5 kasr
// beradi: 1.5 kg = 1500). Ko'rsatish — formatPortions (rk7_shift_model.dart,
// bo'linish YAGONA o'sha yerda).

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

/// SH5 omborining ro'yxat qatori (tovarlarsiz).
class Sh5RemainSklad {
  final int id;
  final int sh5Rid;
  final String name;
  final DateTime? takenAt;
  final int goodsCount;

  const Sh5RemainSklad({
    required this.id,
    required this.sh5Rid,
    required this.name,
    this.takenAt,
    this.goodsCount = 0,
  });

  factory Sh5RemainSklad.fromJson(Map<String, dynamic> json) {
    return Sh5RemainSklad(
      id: _asInt(json['id']),
      sh5Rid: _asInt(json['sh5_rid']),
      name: json['name']?.toString() ?? '',
      takenAt: json['taken_at'] == null
          ? null
          : DateTime.tryParse(json['taken_at'].toString()),
      goodsCount: _asInt(json['goods_count']),
    );
  }
}

/// SH5 omboridagi bitta tovar qoldig'i.
class Sh5RemainGood {
  final int rid;
  final String name;
  final String unit;
  final int qtyMilli; // qoldiq × 1000, BUTUN

  const Sh5RemainGood({
    required this.rid,
    required this.name,
    this.unit = '',
    this.qtyMilli = 0,
  });

  factory Sh5RemainGood.fromJson(Map<String, dynamic> json) {
    return Sh5RemainGood(
      rid: _asInt(json['rid']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      qtyMilli: _asInt(json['qty_milli']),
    );
  }
}

/// GET /api/sh5/remains/{id} javobi: ombor sarlavhasi + tovarlar.
class Sh5RemainDetail {
  final int id;
  final int sh5Rid;
  final String name;
  final DateTime? takenAt;
  final List<Sh5RemainGood> goods;

  const Sh5RemainDetail({
    required this.id,
    required this.sh5Rid,
    required this.name,
    this.takenAt,
    this.goods = const [],
  });

  factory Sh5RemainDetail.fromJson(Map<String, dynamic> json) {
    final rawGoods = json['goods'];
    return Sh5RemainDetail(
      id: _asInt(json['id']),
      sh5Rid: _asInt(json['sh5_rid']),
      name: json['name']?.toString() ?? '',
      takenAt: json['taken_at'] == null
          ? null
          : DateTime.tryParse(json['taken_at'].toString()),
      goods: rawGoods is List
          ? rawGoods
              .whereType<Map>()
              .map((e) => Sh5RemainGood.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
