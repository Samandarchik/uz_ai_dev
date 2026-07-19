// POS (Konak) smena solishtirish (recon) — POS smena yopilganda mone'ga
// yuboradigan qoldiq solishtiruvi: kutilgan qoldiq vs haqiqiy qoldiq.
// Kontrakt: GET /api/pos-recons?days=30[&filial_id=] (faqat admin) —
// data: {recons:[PosRecon...]}.
//
// MUHIM (gram kontrakt): miqdorlar API'da saqlanadigan birlikdagi BUTUN son —
// кг/л mahsulotlarda gr/ml (formatQtyUnit bilan ko'rsatiladi). Pul
// (cash_difference) — butun so'm (tiyin yo'q).

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

class PosReconItem {
  final int productId;
  final String name;
  final String unit;
  final int opening; // smena ochilgandagi qoldiq
  final int received; // smenada qabul qilingan (prixod)
  final int sold; // smenada sotilgan
  final int writtenOff; // spisaniya
  final int corrected; // inventarizatsiya korreksiyasi
  final int actual; // haqiqiy qoldiq (yopilish payti)
  final int diff; // actual - expected

  const PosReconItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.opening,
    required this.received,
    required this.sold,
    required this.writtenOff,
    required this.corrected,
    required this.actual,
    required this.diff,
  });

  // Kutilgan qoldiq (saqlanmaydi — item qiymatlaridan hisoblanadi).
  int get expected => opening + received - sold - writtenOff + corrected;

  factory PosReconItem.fromJson(Map<String, dynamic> json) {
    return PosReconItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      opening: _asInt(json['opening']),
      received: _asInt(json['received']),
      sold: _asInt(json['sold']),
      writtenOff: _asInt(json['written_off']),
      corrected: _asInt(json['corrected']),
      actual: _asInt(json['actual']),
      diff: _asInt(json['diff']),
    );
  }
}

// Bitta smenaning solishtiruvi (filial + smena + sana bo'yicha bitta yozuv).
class PosRecon {
  final int id;
  final int filialId;
  final String filialName;
  final int shiftId;
  final String date; // "YYYY-MM-DD"
  final int cashDifference; // butun so'm (manfiy = kamomad)
  final List<PosReconItem> items;
  final DateTime? created;

  const PosRecon({
    required this.id,
    required this.filialId,
    required this.filialName,
    required this.shiftId,
    required this.date,
    this.cashDifference = 0,
    this.items = const [],
    this.created,
  });

  // Hamma item farqi 0 va kassa farqi 0 — smena toza.
  bool get isClean =>
      cashDifference == 0 && items.every((item) => item.diff == 0);

  // Muammoli qatorlar soni (diff != 0 itemlar + kassa farqi).
  int get problemCount =>
      items.where((item) => item.diff != 0).length +
      (cashDifference != 0 ? 1 : 0);

  factory PosRecon.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PosRecon(
      id: _asInt(json['id']),
      filialId: _asInt(json['filial_id']),
      filialName: json['filial_name']?.toString() ?? '',
      shiftId: _asInt(json['shift_id']),
      date: json['date']?.toString() ?? '',
      cashDifference: _asInt(json['cash_difference']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => PosReconItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      created: json['created'] == null
          ? null
          : DateTime.tryParse(json['created'].toString()),
    );
  }
}

// GET /api/pos-recons javobi: yozuvlar ro'yxati.
class PosReconsResult {
  final List<PosRecon> recons;

  const PosReconsResult({this.recons = const []});

  factory PosReconsResult.fromJson(Map<String, dynamic> json) {
    final rawRecons = json['recons'];
    return PosReconsResult(
      recons: rawRecons is List
          ? rawRecons
              .whereType<Map>()
              .map((e) => PosRecon.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
