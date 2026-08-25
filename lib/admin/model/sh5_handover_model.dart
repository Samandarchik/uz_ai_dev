// admin/model/sh5_handover_model.dart — SH5 smena topshirish/qabul modellari
// (Sh5HandoverDraft, Sh5DraftItem, Sh5Handover, Sh5HandoverItem).
//
// OQIM: kechki kassir topshiradi (StoreHouse soni avto tortiladi, fakt
// kiritiladi) → status "open"; keyingi kassir qabul qiladi (topshirilgan
// sonni tekshiradi) → status "accepted", farq = KAMOMAD.
//
// Kontrakt:
//   GET  /api/sh5/handover/draft?sklad_id= → Sh5HandoverDraft
//   POST /api/sh5/handover                 → Sh5Handover (status open)
//   GET  /api/sh5/handover/open?sklad_id=  → Sh5Handover yoki null
//   POST /api/sh5/handover/{id}/accept     → Sh5Handover (status accepted)
//   GET  /api/sh5/handovers[?sklad_id=&days=] → {handovers:[Sh5HandoverRow]}
//   GET  /api/sh5/handovers/{id}[?diff=1]  → Sh5Handover
//
// MUHIM (son kontrakti): barcha `*_milli` — miqdor × 1000, BUTUN son.
// Ko'rsatish — formatPortions (rk7_shift_model.dart). Serverga float
// YUBORILMAYDI.

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ??
      (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  // Backend bo'sh vaqtni "0001-01-01T00:00:00Z" qilib yuboradi.
  if (d == null || d.year < 1970) return null;
  return d;
}

/// Topshiriq holatlari (backend `status` maydoni).
class Sh5HandoverStatus {
  static const String open = 'open';
  static const String accepted = 'accepted';
}

/// Qoralamadagi bitta qator: StoreHouse soni + oldingi smena topshirgani.
class Sh5DraftItem {
  final int rid;
  final String name;
  final String unit;
  final int sh5Milli;
  final int prevOutMilli;

  const Sh5DraftItem({
    required this.rid,
    required this.name,
    this.unit = '',
    this.sh5Milli = 0,
    this.prevOutMilli = 0,
  });

  factory Sh5DraftItem.fromJson(Map<String, dynamic> json) {
    return Sh5DraftItem(
      rid: _asInt(json['rid']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      sh5Milli: _asInt(json['sh5_milli']),
      prevOutMilli: _asInt(json['prev_out_milli']),
    );
  }
}

/// GET /api/sh5/handover/draft javobi.
class Sh5HandoverDraft {
  final int skladId;
  final String skladName;
  final DateTime? takenAt;
  // hasOpen — bu omborda hali qabul qilinmagan topshiriq bor: avval uni
  // qabul qilish kerak (ekran «Qabul qilish» ga o'tadi).
  final bool hasOpen;
  final int openHandoverId;
  final List<Sh5DraftItem> items;
  // Oldingi topshiriq haqida qisqa ma'lumot (bo'lmasa null).
  final DateTime? prevOutAt;
  final String prevOutUserName;

  const Sh5HandoverDraft({
    required this.skladId,
    this.skladName = '',
    this.takenAt,
    this.hasOpen = false,
    this.openHandoverId = 0,
    this.items = const [],
    this.prevOutAt,
    this.prevOutUserName = '',
  });

  factory Sh5HandoverDraft.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final prev = json['prev'];
    return Sh5HandoverDraft(
      skladId: _asInt(json['sklad_id']),
      skladName: json['sklad_name']?.toString() ?? '',
      takenAt: _asDate(json['taken_at']),
      hasOpen: json['has_open'] == true,
      openHandoverId: _asInt(json['open_handover_id']),
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Sh5DraftItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      prevOutAt: prev is Map ? _asDate(prev['out_at']) : null,
      prevOutUserName:
          prev is Map ? (prev['out_user_name']?.toString() ?? '') : '',
    );
  }
}

/// Topshiriqning bitta tovar qatori.
class Sh5HandoverItem {
  final int rid;
  final String name;
  final String unit;
  // StoreHouse ko'rsatgan son (topshirish payti).
  final int sh5Milli;
  // Topshiruvchi kassir sanagan fakt.
  final int outMilli;
  // Qabul qiluvchi kassir sanagan fakt (qabuldan keyin).
  final int inMilli;
  // Oldingi topshiriqdagi fakt.
  final int prevOutMilli;

  const Sh5HandoverItem({
    required this.rid,
    required this.name,
    this.unit = '',
    this.sh5Milli = 0,
    this.outMilli = 0,
    this.inMilli = 0,
    this.prevOutMilli = 0,
  });

  factory Sh5HandoverItem.fromJson(Map<String, dynamic> json) {
    return Sh5HandoverItem(
      rid: _asInt(json['rid']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      sh5Milli: _asInt(json['sh5_milli']),
      outMilli: _asInt(json['out_milli']),
      inMilli: _asInt(json['in_milli']),
      prevOutMilli: _asInt(json['prev_out_milli']),
    );
  }

  /// Topshirishdagi farq: sanaldi − StoreHouse (manfiy = kam chiqdi).
  int get outDiff => outMilli - sh5Milli;

  /// Qabuldagi farq: sanaldi − topshirilgan (manfiy = kamomad).
  int get inDiff => inMilli - outMilli;
}

/// Bitta smena topshiriq/qabul yozuvi (ro'yxatda itemlarsiz keladi).
class Sh5Handover {
  final int id;
  final int skladId;
  final String skladName;
  final String status;
  final String outUserName;
  final DateTime? outAt;
  final String outNote;
  final String inUserName;
  final DateTime? inAt;
  final String inNote;
  final List<Sh5HandoverItem> items;
  // Ro'yxat javobida item_count keladi, to'liq javobda items.length.
  final int itemCount;

  // Topshirishda StoreHouse sonidan farq qilgan pozitsiyalar.
  final int outDiffCount;
  final int outShortageCount;
  final int outSurplusCount;
  // Qabulda topshirilgan sondan farq qilganlar.
  final int inDiffCount;
  final int shortageCount;
  final int surplusCount;

  const Sh5Handover({
    required this.id,
    required this.skladId,
    this.skladName = '',
    this.status = Sh5HandoverStatus.open,
    this.outUserName = '',
    this.outAt,
    this.outNote = '',
    this.inUserName = '',
    this.inAt,
    this.inNote = '',
    this.items = const [],
    this.itemCount = 0,
    this.outDiffCount = 0,
    this.outShortageCount = 0,
    this.outSurplusCount = 0,
    this.inDiffCount = 0,
    this.shortageCount = 0,
    this.surplusCount = 0,
  });

  factory Sh5Handover.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Sh5HandoverItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Sh5HandoverItem>[];
    return Sh5Handover(
      id: _asInt(json['id']),
      skladId: _asInt(json['sklad_id']),
      skladName: json['sklad_name']?.toString() ?? '',
      status: json['status']?.toString() ?? Sh5HandoverStatus.open,
      outUserName: json['out_user_name']?.toString() ?? '',
      outAt: _asDate(json['out_at']),
      outNote: json['out_note']?.toString() ?? '',
      inUserName: json['in_user_name']?.toString() ?? '',
      inAt: _asDate(json['in_at']),
      inNote: json['in_note']?.toString() ?? '',
      items: items,
      itemCount: json['item_count'] == null
          ? items.length
          : _asInt(json['item_count']),
      outDiffCount: _asInt(json['out_diff_count']),
      outShortageCount: _asInt(json['out_shortage_count']),
      outSurplusCount: _asInt(json['out_surplus_count']),
      inDiffCount: _asInt(json['in_diff_count']),
      shortageCount: _asInt(json['shortage_count']),
      surplusCount: _asInt(json['surplus_count']),
    );
  }

  bool get isOpen => status == Sh5HandoverStatus.open;

  /// Kamomad bormi? Topshirishda ham, qabulda ham hisobga olinadi —
  /// tarixda qizil belgi shu bo'yicha chiqadi.
  bool get hasShortage => shortageCount > 0 || outShortageCount > 0;
}
