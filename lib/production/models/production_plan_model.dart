// production/models/production_plan_model.dart — kunlik ishlab chiqarish
// rejasi (MRP) modeli: GET /api/production/requirements javobi — buyurtma
// qilingan tortlar, П/Ф ehtiyoji (netting bilan) va xomashyo defitsiti.

class PlanCake {
  final int productId;
  final String name;
  final double qty;
  final int orders;

  PlanCake({
    required this.productId,
    required this.name,
    required this.qty,
    required this.orders,
  });

  factory PlanCake.fromJson(Map<String, dynamic> j) => PlanCake(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        orders: (j['orders'] as num?)?.toInt() ?? 0,
      );
}

class PlanPf {
  final int productId;
  final String name;

  /// Ko'rsatish birligi: "шт" (dona-rejim pf) yoki "гр" (gramm-rejim).
  final String unit;
  final double required;
  final double stock;
  final double reserved;
  final double toProduce;

  PlanPf({
    required this.productId,
    required this.name,
    required this.unit,
    required this.required,
    required this.stock,
    required this.reserved,
    required this.toProduce,
  });

  factory PlanPf.fromJson(Map<String, dynamic> j) => PlanPf(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? 'шт',
        required: (j['required'] as num?)?.toDouble() ?? 0,
        stock: (j['stock'] as num?)?.toDouble() ?? 0,
        reserved: (j['reserved'] as num?)?.toDouble() ?? 0,
        toProduce: (j['to_produce'] as num?)?.toDouble() ?? 0,
      );
}

class PlanRaw {
  final int productId;
  final String name;
  final String type;

  /// Miqdorlar API tilida — eng kichik birlik (гр/мл/шт), butun son.
  final int required;
  final int stock;
  final int deficit;

  PlanRaw({
    required this.productId,
    required this.name,
    required this.type,
    required this.required,
    required this.stock,
    required this.deficit,
  });

  factory PlanRaw.fromJson(Map<String, dynamic> j) => PlanRaw(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        required: (j['required'] as num?)?.toInt() ?? 0,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
        deficit: (j['deficit'] as num?)?.toInt() ?? 0,
      );
}

class ProductionPlan {
  final String date;
  final int skladId;
  final List<PlanCake> cakes;
  final List<PlanPf> pf;
  final List<PlanRaw> raw;

  /// Katalogga bog'lanmagan retsept qatorlari (ogohlantirish).
  final List<String> unlinked;

  ProductionPlan({
    required this.date,
    required this.skladId,
    required this.cakes,
    required this.pf,
    required this.raw,
    required this.unlinked,
  });

  factory ProductionPlan.fromJson(Map<String, dynamic> j) => ProductionPlan(
        date: j['date']?.toString() ?? '',
        skladId: (j['sklad_id'] as num?)?.toInt() ?? 1,
        cakes: ((j['cakes'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => PlanCake.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        pf: ((j['pf'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => PlanPf.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        raw: ((j['raw'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => PlanRaw.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        unlinked:
            ((j['unlinked'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}
