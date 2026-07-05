// Ombor o'zi bergan buyurtmalar modeli.
// Backend javobi:
// { "success": true, "message": "...", "data": [ {order}, ... ] }
// Har order:
// { "id":1, "order_id":"26-06-20-1", "sklad_id":1, "sklad_name":"...",
//   "status":"created"|"narxlandi", "total":3000, "created":"...",
//   "items":[ {"product_id":5,"name":"Un","count":3,"type":"kg",
//              "taken":6,"subtotal":3000} ] }

class OmborOrder {
  final int id;
  final String orderId;
  final String skladName;
  final String status; // "created" | "narxlandi" | "qabul_qilindi"
  final double total;
  // Rasxod (xarajat) itemlar yig'indisi. total rasxodni O'Z ICHIGA OLMAYDI;
  // umumiy chek = total + expensesTotal.
  final double expensesTotal;
  // Ombor qabul qilgandan keyin kamaygan jami summa. total — narxlangan
  // to'liq summa bo'lib qoladi. receivedTotal != total (va >0) bo'lsa —
  // kam qabul qilingan.
  final double receivedTotal;
  final String created;
  final List<OmborOrderItem> items;
  // Omborchi qabul qilganda yuborilgan video(lar) (relativ /static/...).
  final List<String> videoUrls;

  OmborOrder({
    required this.id,
    required this.orderId,
    required this.skladName,
    required this.status,
    required this.total,
    this.expensesTotal = 0,
    this.receivedTotal = 0,
    required this.created,
    required this.items,
    this.videoUrls = const [],
  });

  // Yuk keltiruvchi narx qo'yganmi (omborchi endi qabul qila oladi).
  bool get isPriced => status == 'narxlandi';

  // Hali narxlanmagan buyurtma — lekin omborchi baribir qabul qila oladi
  // (kelgan soni + rasm/video bilan). Ombor ekrani faqat o'z sklad
  // buyurtmalarini ko'rsatadi, shuning uchun narxlanmagan va qabul
  // qilinmagan HAR QANDAY status shu qatorga kiradi — jumladan eski
  // rol-headersiz yaratilib printer yo'liga tushgan "sent_to_printer"
  // yoki revert'dan keyingi "pending" ham.
  bool get isCreated => !isPriced && !isAccepted;

  // Omborchi qabul qilib videoni yuborganmi.
  bool get isAccepted => status == 'qabul_qilindi';

  factory OmborOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<OmborOrderItem> parsedItems = (rawItems is List)
        ? rawItems
            .map((e) => OmborOrderItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OmborOrderItem>[];

    final rawVideos = json['video_urls'];
    final List<String> videos = (rawVideos is List)
        ? rawVideos.map((e) => e.toString()).toList()
        : <String>[];

    return OmborOrder(
      id: json['id'] ?? 0,
      orderId: json['order_id']?.toString() ?? '',
      skladName: json['sklad_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      total: _toDouble(json['total']),
      expensesTotal: _toDouble(json['expenses_total']),
      receivedTotal: _toDouble(json['received_total']),
      created: json['created']?.toString() ?? '',
      items: parsedItems,
      videoUrls: videos,
    );
  }
}

class OmborOrderItem {
  final int productId;
  final String name;
  final double count;
  final String type;
  final double taken;
  final double subtotal;
  // Omborchi kiritgan haqiqatda kelgan miqdor (taken'dan kam bo'lsa kamomad).
  final double received;
  // Omborchi qabul qilganda yuborgan rasm/video (relativ /static/...).
  final String imageUrl;
  final String videoUrl;
  // Item turi: '' — oddiy mahsulot, 'proche' — yuk keltiruvchi qo'shgan
  // qo'shimcha mahsulot, 'rasxod' — xarajat/xizmat (qabul qilinmaydi).
  final String itemType;
  // Omborchi shu mahsulotni alohida qabul qilganmi (item darajasida).
  // Hamma item qabul bo'lsa backend order statusini 'qabul_qilindi' qiladi.
  final bool accepted;

  OmborOrderItem({
    required this.productId,
    required this.name,
    required this.count,
    required this.type,
    required this.taken,
    required this.subtotal,
    this.received = 0,
    this.imageUrl = '',
    this.videoUrl = '',
    this.itemType = '',
    this.accepted = false,
  });

  bool get isRasxod => itemType == 'rasxod';
  bool get isProche => itemType == 'proche';

  factory OmborOrderItem.fromJson(Map<String, dynamic> json) {
    return OmborOrderItem(
      productId: json['product_id'] ?? 0,
      name: json['name']?.toString() ?? '',
      count: _toDouble(json['count']),
      type: json['type']?.toString() ?? '',
      taken: _toDouble(json['taken']),
      subtotal: _toDouble(json['subtotal']),
      received: _toDouble(json['received']),
      imageUrl: json['image_url']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? '',
      accepted: json['accepted'] == true,
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// Javobdagi `data` massivni OmborOrder ro'yxatiga aylantirish.
List<OmborOrder> parseOmborOrders(dynamic data) {
  if (data is List) {
    return data
        .map((e) => OmborOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return <OmborOrder>[];
}
