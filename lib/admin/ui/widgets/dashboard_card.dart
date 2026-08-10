// admin/ui/widgets/dashboard_card.dart — admin bosh ekran tepasidagi
// boshqaruv paneli (DashboardCard): bugungi buyurtmalar, ishlab chiqarish
// holati, kam qolgan xomashyo — GET /api/dashboard'dan o'zi yuklaydi
// (xatoda JIM: panel shunchaki ko'rinmaydi, bosh ekran ishlayveradi).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/ui/admin_stock_ui.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/production/ui/production_plan_page.dart';

class DashboardData {
  final int todayOrders;
  final double todayPieces;
  final int pendingPurchase;
  final int prodTotal;
  final int prodTayyor;
  final int prodAktiv;
  final int lowStockTotal;

  DashboardData({
    required this.todayOrders,
    required this.todayPieces,
    required this.pendingPurchase,
    required this.prodTotal,
    required this.prodTayyor,
    required this.prodAktiv,
    required this.lowStockTotal,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final prod = (j['production'] as Map?) ?? {};
    return DashboardData(
      todayOrders: (j['today_orders'] as num?)?.toInt() ?? 0,
      todayPieces: (j['today_pieces'] as num?)?.toDouble() ?? 0,
      pendingPurchase: (j['pending_purchase'] as num?)?.toInt() ?? 0,
      prodTotal: (prod['total'] as num?)?.toInt() ?? 0,
      prodTayyor: (prod['tayyor'] as num?)?.toInt() ?? 0,
      prodAktiv: (prod['aktiv'] as num?)?.toInt() ?? 0,
      lowStockTotal: (j['low_stock_total'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardCard extends StatefulWidget {
  const DashboardCard({super.key});

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await sl<Dio>().get(AppUrls.dashboard);
      if (!mounted) return;
      setState(() => _data = DashboardData.fromJson(
          Map<String, dynamic>.from(response.data['data'])));
    } catch (_) {
      // jim — panel ko'rinmaydi
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _stat('Bugungi buyurtma', '${d.todayOrders}',
              sub: d.todayPieces > 0
                  ? '${d.todayPieces == d.todayPieces.roundToDouble() ? d.todayPieces.toInt() : d.todayPieces} dona'
                  : null,
              icon: Icons.receipt_long,
              color: Colors.blue),
          const SizedBox(width: 8),
          _stat('Ishlab chiqarish', '${d.prodAktiv} / ${d.prodTotal}',
              sub: 'tayyor: ${d.prodTayyor}',
              icon: Icons.event_note,
              color: Colors.purple,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProductionPlanPage()))),
          const SizedBox(width: 8),
          _stat('Ochiq xarid', '${d.pendingPurchase}',
              sub: 'buyurtma', icon: Icons.shopping_cart_outlined,
              color: Colors.teal),
        ]),
        if (d.lowStockTotal > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminStockUi())),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          '${d.lowStockTotal} ta xomashyo chegaradan kam qoldi',
                          style: const TextStyle(fontSize: 13))),
                  const Icon(Icons.chevron_right, size: 18),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stat(String title, String value,
      {String? sub, required IconData icon, required Color color, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              if (sub != null)
                Text(sub,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
