// Inventarizatsiya dalolatnomasi (акт инвентаризации) modellari.
// Kontrakt: GET /api/stock/inventories[?sklad_id=N&limit=K] — ro'yxat
// (items'siz), GET /api/stock/inventories/{id} — items bilan.
//
// MUHIM ikki kontrakt:
//  • Miqdorlar (system_qty/actual_qty/diff) — gramm kontrakti: кг/л uchun
//    BUTUN гр/мл (10000 = 10 кг). Ko'rsatishda formatQty(x, type).
//  • Pul (unit_price/amount/shortage_total/surplus_total) — BUTUN so'm.
//    unit_price 1 кг / 1 литр / 1 шт / 1 м narxi bo'lib, inventarizatsiya
//    paytida SURATGA OLINGAN (bugungi narx emas); 0 — o'shanda narx yo'q edi.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

// Dalolatnomaning bitta qatori — FAQAT farqi chiqqan mahsulotlar saqlanadi
// (mos kelgan qatorlar yozilmaydi).
class InventoryActItem {
  final int productId;
  final String name;
  final String type; // mahsulot birligi: кг | литр | шт | м ...
  final int systemQty; // tizimdagi qoldiq (gr/ml)
  final int actualQty; // real sanalgan (gr/ml)
  final int diff; // actual − system; manfiy = kamomad
  final int unitPrice; // 1 кг/л/шт/м narxi, butun so'm; 0 = narx yo'q
  final int amount; // diff ning pul qiymati, butun so'm; manfiy = zarar

  const InventoryActItem({
    required this.productId,
    this.name = '',
    this.type = '',
    this.systemQty = 0,
    this.actualQty = 0,
    this.diff = 0,
    this.unitPrice = 0,
    this.amount = 0,
  });

  factory InventoryActItem.fromJson(Map<String, dynamic> json) {
    return InventoryActItem(
      productId: _asInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      systemQty: _asInt(json['system_qty']),
      actualQty: _asInt(json['actual_qty']),
      diff: _asInt(json['diff']),
      unitPrice: _asInt(json['unit_price']),
      amount: _asInt(json['amount']),
    );
  }

  static List<InventoryActItem> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => InventoryActItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

// Bitta dalolatnoma. Ro'yxat javobida `items` bo'sh — u faqat
// /api/stock/inventories/{id} da to'ladi.
class InventoryAct {
  final int id;
  final int skladId;
  final String skladName;
  final int userId;
  final String userName;
  final DateTime? created;
  final int countedItems; // nechta pozitsiya sanaldi
  final int diffItems; // nechtasida farq chiqdi
  final int shortageTotal; // manfiy amount'lar yig'indisi — MUSBAT son
  final int surplusTotal; // musbat amount'lar yig'indisi
  final List<InventoryActItem> items;

  const InventoryAct({
    required this.id,
    this.skladId = 0,
    this.skladName = '',
    this.userId = 0,
    this.userName = '',
    this.created,
    this.countedItems = 0,
    this.diffItems = 0,
    this.shortageTotal = 0,
    this.surplusTotal = 0,
    this.items = const [],
  });

  // Farq umuman chiqmagan inventarizatsiya (pul bo'yicha).
  bool get noMoneyDiff => shortageTotal == 0 && surplusTotal == 0;

  factory InventoryAct.fromJson(Map<String, dynamic> json) {
    return InventoryAct(
      id: _asInt(json['id']),
      skladId: _asInt(json['sklad_id']),
      skladName: json['sklad_name']?.toString() ?? '',
      userId: _asInt(json['user_id']),
      userName: json['user_name']?.toString() ?? '',
      created: DateTime.tryParse(json['created']?.toString() ?? ''),
      countedItems: _asInt(json['counted_items']),
      diffItems: _asInt(json['diff_items']),
      shortageTotal: _asInt(json['shortage_total']),
      surplusTotal: _asInt(json['surplus_total']),
      items: InventoryActItem.listFromJson(json['items']),
    );
  }

  static List<InventoryAct> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => InventoryAct.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
