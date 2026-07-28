// core/widgets/order_period.dart — buyurtma ro'yxatlari uchun davr tanlagichi: OrderPeriod
// enum (30/90 kun, hammasi) va AppBar'da ishlatiladigan OrderPeriodButton (PopupMenuButton).
import 'package:flutter/material.dart';

// Buyurtmalar tarixi oynasi. Server yopiq buyurtmalarni standart holatda
// faqat oxirgi 30 kun uchun qaytaradi (aktiv buyurtmalar har doim keladi):
//   last30 -> param yuborilmaydi (server default 30 kun)
//   last90 -> ?days=90
//   all    -> ?all=1 (to'liq tarix)
// Tanlov saqlanmaydi — har ekran o'z holatida ushlaydi, ilova qayta
// ochilganda default (30 kun) qaytadi.
enum OrderPeriod {
  last30('Oxirgi 30 kun'),
  last90('Oxirgi 90 kun'),
  all('Hammasi');

  const OrderPeriod(this.label);
  final String label;

  // API'ga yuboriladigan days qiymati (null — param yuborilmaydi, server
  // default 30 kun ishlaydi).
  int? get days => this == OrderPeriod.last90 ? 90 : null;

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
