import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';

// Yuk keltiruvchi profili / statistikasi.
// Qancha yuk olib kelgan, qanchasi qabul qilingan, qanchasi qabul qilinmagan
// (kamomad), qancha sotib olgan — barchasini umumiy va sklad bo'yicha ko'rsatadi.
class YukProfileUi extends StatelessWidget {
  final List<int> sklads; // foydalanuvchining skladlari (tartibni saqlaydi)
  const YukProfileUi({super.key, required this.sklads});

  static const Color _bg = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<YukProvider>(
        builder: (context, provider, _) {
          // Umumiy (barcha sklad) statistikasi.
          final overall = _Stats.from(provider.orders);
          // Sklad bo'yicha.
          final perSklad = sklads
              .map((id) => MapEntry(
                    id,
                    _Stats.from(
                      provider.orders.where((o) => o.skladId == id),
                    ),
                  ))
              .toList();

          return RefreshIndicator(
            onRefresh: () => provider.fetchOrders(),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const Text(
                  'Umumiy',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryGrid(stats: overall),
                const SizedBox(height: 22),
                const Text(
                  'Sklad bo\'yicha',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                ...perSklad.map(
                  (e) => _SkladCard(
                    title: _skladNames[e.key] ?? 'Sklad ${e.key}',
                    stats: e.value,
                  ),
                ),
                const SizedBox(height: 22),
                // Kamomad bo'lgan buyurtmalar (qabul qilinmagan qismi bor).
                if (overall.shortageOrders.isNotEmpty) ...[
                  const Text(
                    'Kamomad bo\'lgan buyurtmalar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...overall.shortageOrders.map((o) => _ShortageTile(order: o)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Sklad nomlari (yuk_home_ui dagi kSkladNames bilan bir xil).
const Map<int, String> _skladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
};

// Buyurtmalar to'plamidan hisoblangan statistika.
class _Stats {
  final int sentCount; // yuborilgan (narxlangan + qabul qilingan)
  final int acceptedCount; // qabul qilingan
  final int pendingCount; // narxlangan, lekin hali qabul qilinmagan
  final double brought; // jami olib kelingan summa (yuborilgan total)
  final double accepted; // qabul qilingan summa
  final double shortage; // qabul qilinmagan (kamomad) summa
  final List<YukOrder> shortageOrders; // kamomadli buyurtmalar

  _Stats({
    required this.sentCount,
    required this.acceptedCount,
    required this.pendingCount,
    required this.brought,
    required this.accepted,
    required this.shortage,
    required this.shortageOrders,
  });

  factory _Stats.from(Iterable<YukOrder> orders) {
    int sent = 0, acc = 0, pend = 0;
    double brought = 0, accepted = 0, shortage = 0;
    final shortageOrders = <YukOrder>[];

    for (final o in orders) {
      final isAccepted = o.status == 'qabul_qilindi';
      final isPriced = o.status == 'narxlandi';
      if (!isAccepted && !isPriced) continue; // hali yuborilmagan

      sent++;
      brought += o.total.toDouble();

      if (isPriced) {
        pend++;
      } else {
        acc++;
        // Qabul qilingan summa: kam qabul qilingan bo'lsa received_total,
        // aks holda to'liq total.
        final eff = (o.receivedTotal > 0 && o.receivedTotal != o.total)
            ? o.receivedTotal
            : o.total.toDouble();
        accepted += eff;
        final diff = o.total.toDouble() - eff;
        if (diff > 0.0001) {
          shortage += diff;
          shortageOrders.add(o);
        }
      }
    }

    return _Stats(
      sentCount: sent,
      acceptedCount: acc,
      pendingCount: pend,
      brought: brought,
      accepted: accepted,
      shortage: shortage,
      shortageOrders: shortageOrders,
    );
  }
}

// Umumiy 4 ta ko'rsatkich kartasi (2x2 grid).
class _SummaryGrid extends StatelessWidget {
  final _Stats stats;
  const _SummaryGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Olib kelingan',
                value: '${_money(stats.brought)} so\'m',
                sub: '${stats.sentCount} ta buyurtma',
                color: YukProfileUi._accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Qabul qilingan',
                value: '${_money(stats.accepted)} so\'m',
                sub: '${stats.acceptedCount} ta',
                color: YukProfileUi._green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Qabul qilinmagan',
                value: '${_money(stats.shortage)} so\'m',
                sub: 'kamomad',
                color: YukProfileUi._red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// Bitta sklad bo'yicha qisqa statistika.
class _SkladCard extends StatelessWidget {
  final String title;
  final _Stats stats;
  const _SkladCard({required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${stats.sentCount} ta',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const Divider(height: 16),
          _row('Olib kelingan', '${_money(stats.brought)} so\'m',
              YukProfileUi._accent),
          _row('Qabul qilingan', '${_money(stats.accepted)} so\'m',
              YukProfileUi._green),
          _row('Qabul qilinmagan', '${_money(stats.shortage)} so\'m',
              YukProfileUi._red),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Kamomad bo'lgan buyurtma: olib kelingan -> qabul qilingan + farq.
class _ShortageTile extends StatelessWidget {
  final YukOrder order;
  const _ShortageTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final eff = (order.receivedTotal > 0 && order.receivedTotal != order.total)
        ? order.receivedTotal
        : order.total.toDouble();
    final diff = order.total.toDouble() - eff;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderId}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_skladNames[order.skladId] ?? 'Sklad ${order.skladId}'}'
                  ' • ${order.username}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_money(order.total)} so\'m',
                style: const TextStyle(
                  fontSize: 12,
                  color: YukProfileUi._red,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: YukProfileUi._red,
                ),
              ),
              Text(
                '${_money(eff)} so\'m',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: YukProfileUi._green,
                ),
              ),
              Text(
                '-${_money(diff)} so\'m',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: YukProfileUi._red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Minglik ajratgich bilan summa (yuk_home_ui dagi _formatMoney bilan bir xil).
String _money(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
