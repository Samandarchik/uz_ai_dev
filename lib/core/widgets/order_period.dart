// core/widgets/order_period.dart — buyurtma ro'yxatlari uchun davr tanlagichi: OrderPeriod
// enum (30/90 kun, hammasi) va AppBar'da ishlatiladigan OrderPeriodButton (PopupMenuButton).
import 'package:flutter/material.dart';

// Buyurtmalar tarixi oynasi. Server YOPIQ buyurtmalarni faqat shu oyna
// ichida qaytaradi (aktiv buyurtmalar oynadan qat'i nazar har doim keladi):
//   last3  -> ?days=3
//   last30 -> ?days=30 (server defaulti ham shu)
//   last90 -> ?days=90
//   all    -> ?all=1 (to'liq tarix)
//
// Har ekran O'Z defaultini tanlaydi (sotuvchi — last3, ombor/bugalter —
// last30). Tanlov saqlanmaydi: ilova qayta ochilganda ekran defaultiga
// qaytadi.
enum OrderPeriod {
  last3('Oxirgi 3 kun', 3),
  last30('Oxirgi 30 kun', 30),
  last90('Oxirgi 90 kun', 90),
  all('Hammasi', null);

  const OrderPeriod(this.label, this.days);

  final String label;

  // API'ga yuboriladigan ?days qiymati. `all` da null — o'rniga ?all=1
  // yuboriladi (isAll).
  final int? days;

  // API'ga ?all=1 yuboriladimi (to'liq tarix).
  bool get isAll => this == OrderPeriod.all;
}

// AppBar uchun davr tanlash tugmasi: faol variant oldida check belgisi,
// yangi variant tanlanganda onChanged chaqiriladi (ekran refetch qiladi).
class OrderPeriodButton extends StatelessWidget {
  final OrderPeriod value;
  final ValueChanged<OrderPeriod> onChanged;
  const OrderPeriodButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<OrderPeriod>(
      tooltip: 'Davr',
      icon: const Icon(Icons.date_range),
      onSelected: (p) {
        if (p != value) onChanged(p);
      },
      itemBuilder: (context) => [
        for (final p in OrderPeriod.values)
          PopupMenuItem<OrderPeriod>(
            value: p,
            child: Row(
              children: [
                Icon(
                  Icons.check,
                  size: 18,
                  color: p == value ? Colors.black87 : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(p.label),
              ],
            ),
          ),
      ],
    );
  }
}
