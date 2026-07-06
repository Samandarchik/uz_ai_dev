// Targovli (qilinadigan_ishlar) tizimidan yuk keltiruvchiga yuborilgan pul.
// Kassir u tomonda yuboradi; yuk keltiruvchi shu ilovada "Qabul qilish" yoki
// "Rad etish" qiladi. Qabul qilinsa summa kunlik hisob daftariga (ledger)
// prixod bo'lib tushadi va targovli tomonga "qabul qilindi" qaytariladi.
class YukTransfer {
  final int id;
  final int userId;
  final String userName;
  final double amount;
  // Kassir yozgan izoh (bo'sh bo'lishi mumkin).
  final String comment;
  // Targovli tomonda pulni yuborgan kassir ismi.
  final String senderName;
  // pending | accepted | rejected
  final String status;
  // Rad etish sababi (reject'da yoziladi).
  final String reviewText;
  final DateTime? created;

  const YukTransfer({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    this.comment = '',
    this.senderName = '',
    this.status = 'pending',
    this.reviewText = '',
    this.created,
  });

  bool get isPending => status == 'pending';

  factory YukTransfer.fromJson(Map<String, dynamic> json) => YukTransfer(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        userName: json['user_name']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        comment: json['comment']?.toString() ?? '',
        senderName: json['sender_name']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        reviewText: json['review_text']?.toString() ?? '',
        created: DateTime.tryParse(json['created']?.toString() ?? ''),
      );
}

// GET /api/yuk/transfers javobidagi data ro'yxatini parse qiladi.
List<YukTransfer> parseYukTransfers(dynamic data) {
  if (data is! List) return [];
  return [
    for (final e in data)
      if (e is Map) YukTransfer.fromJson(Map<String, dynamic>.from(e)),
  ];
}
