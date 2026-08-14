// admin/model/rk7_shift_model.dart — RK7 import qilingan smena modellari
// (Rk7Shift, Rk7ShiftItem, Rk7ShiftVoid, Rk7Deduction, Rk7UnmappedDish) +
// qty_milli → porsiya matni (formatPortions).
//
// Kontrakt (PLAN_RK7 §3, §4): GET /api/rk7/shifts?days=30 — {shifts:[...]},
// GET /api/rk7/shifts/{id} — bitta smena to'liq.
//
// MUHIM (son kontrakti): `qty_milli` — milli-porsiya, BUTUN son
// (999 = 0.999 porsiya). Pul (amount/total) — BUTUN so'm (tiyin yo'q).
// Serverga float YUBORILMAYDI.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().toLowerCase();
  return s == 'true' || s == '1';
}

/// Ro'yxat javobida soni alohida maydonda kelishi mumkin (`items_count`),
/// detal javobida esa massivning uzunligi bilan. Ikkalasini ham qo'llaydi.
int _countOf(Map<String, dynamic> json, String countKey, String listKey) {
  final raw = json[countKey];
  if (raw != null) return _asInt(raw);
  final list = json[listKey];
  return list is List ? list.length : 0;
}

/// `qty_milli` (milli-porsiya, butun) → porsiya matni: 3000 → "3",
/// 999 → "0.999", 1500 → "1.5" (keraksiz nol kasrlarsiz).
///
/// Bu кг/л gram kontrakti EMAS (u — `core/utils/qty_units.dart`), RK7
/// porsiyasi alohida kontrakt; shuning uchun bo'linish YAGONA shu yerda.
String formatPortions(int qtyMilli) {
  final v = qtyMilli / 1000;
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
}

/// Smenadagi sotuv satri (TYPE=0) — jamlangan (nuqta, taom, to'lov turi).
class Rk7ShiftItem {
  final String uotGuid;
  final String dishGuid;
  final String dishName;
  final String payGuid;
  final String payName;
  final int qtyMilli; // milli-porsiya, butun
  final int amount; // butun so'm
  final int discount; // butun so'm

  const Rk7ShiftItem({
    this.uotGuid = '',
    this.dishGuid = '',
    this.dishName = '',
    this.payGuid = '',
    this.payName = '',
    this.qtyMilli = 0,
    this.amount = 0,
    this.discount = 0,
  });

  factory Rk7ShiftItem.fromJson(Map<String, dynamic> json) {
    return Rk7ShiftItem(
      uotGuid: json['uot_guid']?.toString() ?? '',
      dishGuid: json['dish_guid']?.toString() ?? '',
      dishName: json['dish_name']?.toString() ?? '',
      payGuid: json['pay_guid']?.toString() ?? '',
      payName: json['pay_name']?.toString() ?? '',
      qtyMilli: _asInt(json['qty_milli']),
      amount: _asInt(json['amount']),
      discount: _asInt(json['discount']),
    );
  }
}

/// Bekor qilingan/qaytarilgan satr (TYPE=1) — qoldiqqa ta'sir qilmaydi.
class Rk7ShiftVoid {
  final String uotGuid;
  final String dishGuid;
  final String dishName;
  final String voidGuid;
  final int qtyMilli;
  final int amount; // butun so'm

  const Rk7ShiftVoid({
    this.uotGuid = '',
    this.dishGuid = '',
    this.dishName = '',
    this.voidGuid = '',
    this.qtyMilli = 0,
    this.amount = 0,
  });

  factory Rk7ShiftVoid.fromJson(Map<String, dynamic> json) {
    return Rk7ShiftVoid(
      uotGuid: json['uot_guid']?.toString() ?? '',
      dishGuid: json['dish_guid']?.toString() ?? '',
      dishName: json['dish_name']?.toString() ?? '',
      voidGuid: json['void_guid']?.toString() ?? '',
      qtyMilli: _asInt(json['qty_milli']),
      amount: _asInt(json['amount']),
    );
  }
}

/// Smena bo'yicha QO'LLANGAN skladdan yechish (reimportda teskarisi bajariladi).
/// `qty` — mahsulotning saqlash birligida BUTUN son.
class Rk7Deduction {
  final int skladId;
  final int productId;
  final String productName; // backend qo'shsa ko'rsatiladi
  final String unit;
  final int qty;

  const Rk7Deduction({
    this.skladId = 0,
    this.productId = 0,
    this.productName = '',
    this.unit = '',
    this.qty = 0,
  });

  factory Rk7Deduction.fromJson(Map<String, dynamic> json) {
    return Rk7Deduction(
      skladId: _asInt(json['sklad_id']),
      productId: _asInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      qty: _asInt(json['qty']),
    );
  }
}

/// Bog'lanmagan taom. Ikki joyda ishlatiladi:
///   - smena detali `unmapped[]` — {dish_guid, dish_name, qty_milli};
///   - GET /api/rk7/unmapped — {dish_guid, dish_name, last_date, total_qty_milli}.
class Rk7UnmappedDish {
  final String dishGuid;
  final String dishName;
  final String lastDate; // "YYYY-MM-DD" (faqat /unmapped javobida)
  final int qtyMilli; // total_qty_milli yoki qty_milli

  const Rk7UnmappedDish({
    this.dishGuid = '',
    this.dishName = '',
    this.lastDate = '',
    this.qtyMilli = 0,
  });

  factory Rk7UnmappedDish.fromJson(Map<String, dynamic> json) {
    return Rk7UnmappedDish(
      dishGuid: json['dish_guid']?.toString() ?? '',
      dishName: json['dish_name']?.toString() ?? '',
      lastDate: json['last_date']?.toString() ?? '',
      qtyMilli: json['total_qty_milli'] != null
          ? _asInt(json['total_qty_milli'])
          : _asInt(json['qty_milli']),
    );
  }
}

/// Import qilingan RK7 smenasi. Ro'yxatda faqat sarlavha maydonlari va
/// sanoqlar keladi; detalda (`/api/rk7/shifts/{id}`) massivlar ham to'ladi.
class Rk7Shift {
  final int id;
  final String restaurantGuid;
  final String shiftDate; // "YYYY-MM-DD"
  final int shiftNum;
  final int midServer;
  final int total; // butun so'm
  final int voidTotal; // butun so'm
  final int itemsCount;
  final int deductedCount;
  final int unmappedCount;
  final List<Rk7ShiftItem> items;
  final List<Rk7ShiftVoid> voids;
  final List<Rk7Deduction> deductions;
  final List<Rk7UnmappedDish> unmapped;
  final DateTime? created;

  const Rk7Shift({
    this.id = 0,
    this.restaurantGuid = '',
    this.shiftDate = '',
    this.shiftNum = 0,
    this.midServer = 0,
    this.total = 0,
    this.voidTotal = 0,
    this.itemsCount = 0,
    this.deductedCount = 0,
    this.unmappedCount = 0,
    this.items = const [],
    this.voids = const [],
    this.deductions = const [],
    this.unmapped = const [],
    this.created,
  });

  factory Rk7Shift.fromJson(Map<String, dynamic> json) {
    return Rk7Shift(
      id: _asInt(json['id']),
      restaurantGuid: json['restaurant_guid']?.toString() ?? '',
      shiftDate: json['shift_date']?.toString() ?? '',
      shiftNum: _asInt(json['shift_num']),
      midServer: _asInt(json['mid_server']),
      total: _asInt(json['total']),
      voidTotal: _asInt(json['void_total']),
      itemsCount: _countOf(json, 'items_count', 'items'),
      deductedCount: _countOf(json, 'deducted_count', 'deductions'),
      unmappedCount: _countOf(json, 'unmapped_count', 'unmapped'),
      items: _list(json['items'], Rk7ShiftItem.fromJson),
      voids: _list(json['voids'], Rk7ShiftVoid.fromJson),
      deductions: _list(json['deductions'], Rk7Deduction.fromJson),
      unmapped: _list(json['unmapped'], Rk7UnmappedDish.fromJson),
      created: json['created'] == null
          ? null
          : DateTime.tryParse(json['created'].toString()),
    );
  }
}

/// JSON massivini modellar ro'yxatiga o'giradi (null/notug'ri tur — bo'sh).
List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Ichki `_list` ni boshqa RK7 modellari ham ishlatishi uchun ochiq nom.
List<T> rk7ListFrom<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) =>
    _list(raw, fromJson);

/// `active` maydonini o'qish (bool/int/satr) — boshqa RK7 modellari uchun.
bool rk7AsBool(dynamic v) => _asBool(v);

/// Butun sonni turli JSON turlaridan o'qish — boshqa RK7 modellari uchun.
int rk7AsInt(dynamic v) => _asInt(v);
