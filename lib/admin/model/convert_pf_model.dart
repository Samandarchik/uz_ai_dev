// POST /api/techcards/convert-pf javobi (data) — takrorlangan bir xil
// bazalarni полуфабрикат mahsulotlarga aylantirish hisoboti.
// created: yaratilgan pf guruhlari (a'zo mahsulot nomlari bilan),
// skipped: o'tkazilmaganlar (sabab TAYYOR o'zbekcha matn — aynan ko'rsatiladi).

class ConvertPfCreated {
  final int pfProductId;
  final String name;
  final List<String> members;

  const ConvertPfCreated({
    required this.pfProductId,
    required this.name,
    this.members = const [],
  });

  factory ConvertPfCreated.fromJson(Map<String, dynamic> json) {
    return ConvertPfCreated(
      pfProductId: (json['pf_product_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      members: (json['members'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  static List<ConvertPfCreated> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ConvertPfCreated.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

class ConvertPfSkipped {
  final String name;
  final String reason;

  const ConvertPfSkipped({required this.name, required this.reason});

  factory ConvertPfSkipped.fromJson(Map<String, dynamic> json) {
    return ConvertPfSkipped(
      name: json['name']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  static List<ConvertPfSkipped> listFromJson(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ConvertPfSkipped.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

class ConvertPfReport {
  final List<ConvertPfCreated> created;
  final List<ConvertPfSkipped> skipped;

  const ConvertPfReport({this.created = const [], this.skipped = const []});

  factory ConvertPfReport.fromJson(Map<String, dynamic> json) {
    return ConvertPfReport(
      created: ConvertPfCreated.listFromJson(json['created']),
      skipped: ConvertPfSkipped.listFromJson(json['skipped']),
    );
  }
}
