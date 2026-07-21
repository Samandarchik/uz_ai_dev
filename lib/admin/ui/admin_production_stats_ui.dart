// admin/ui/admin_production_stats_ui.dart — ishlab chiqarish statistikasi ekrani
// (AdminProductionStatsUi): ProductionService.fetchStats (7/30/90 kun); progress
// chiziqlar va gorizontal barlar, chart paketisiz. Admin/bugalter uchun.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/production/models/production_stats_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';

// Ishlab chiqarish statistikasi (F6) — admin va bugalter uchun.
// GET /api/production/stats?from=&to= (default 30 kun). Oddiy vidjetlar,
// chart paketi YO'Q: progress chiziqlar va gorizontal barlar.
class AdminProductionStatsUi extends StatefulWidget {
  const AdminProductionStatsUi({super.key});

  @override
  State<AdminProductionStatsUi> createState() => _AdminProductionStatsUiState();
}

class _AdminProductionStatsUiState extends State<AdminProductionStatsUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);

  static const List<int> _periods = [7, 30, 90];
  int _days = 30;

  late Future<ProductionStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProductionStats> _load() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    return ProductionService().fetchStats(
      from: fmt.format(now.subtract(Duration(days: _days))),
      to: fmt.format(now),
    );
  }

  void _refresh() => setState(() => _future = _load());

  void _setPeriod(int days) {
    if (_days == days) return;
    setState(() {
      _days = days;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Ishlab chiqarish statistikasi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Davr tanlash chiplari.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                for (final d in _periods)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$d kun'),
                      selected: _days == d,
                      onSelected: (_) => _setPeriod(d),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _days == d ? Colors.white : Colors.black54,
                      ),
                      selectedColor: _accent,
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: _days == d ? _accent : Colors.grey.shade300,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<ProductionStats>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error
                                .toString()
                                .replaceFirst('Exception: ', ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refresh,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Qayta urinish'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _StatsBody(stats: snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  static const Color _accent = Color(0xFFC5A97B);

  final ProductionStats stats;

  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // Yig'indi kartalari.
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Buyurtmalar',
                '${stats.ordersTotal}',
                subtitle: 'tayyor: ${stats.ordersTayyor}',
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Buyurtma qilingan',
                '${stats.piecesOrdered}',
                subtitle: 'dona',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Tayyor',
                '${stats.piecesDone}',
                subtitle: 'dona',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),

        if (stats.byProduct.isNotEmpty) ...[
          _sectionTitle('Mahsulot bo\'yicha'),
          _sectionCard([
            for (final p in stats.byProduct) _productRow(p),
          ]),
        ],

        if (stats.byShef.isNotEmpty) ...[
          _sectionTitle('Shef bo\'yicha'),
          _sectionCard([
            for (final s in stats.byShef) _shefRow(s),
          ]),
        ],

        if (stats.byDay.isNotEmpty) ...[
          _sectionTitle('Kunlar bo\'yicha'),
          _sectionCard([
            for (final d in stats.byDay) _dayRow(d),
          ]),
        ],

        if (stats.stageAvgHours.isNotEmpty) ...[
          _sectionTitle('Bo\'lim tezligi'),
          _sectionCard([
            for (final st in stats.stageAvgHours) _stageRow(st),
          ]),
        ],

        if (stats.ordersTotal == 0)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'Tanlangan davrda buyurtmalar yo\'q',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
      ],
    );
  }

  // ---- Yig'indi kartasi ----

  Widget _summaryCard(String title, String value,
      {String subtitle = '', required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle.isEmpty ? title : '$title • $subtitle',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ---- Bo'lim sarlavhasi / kartasi ----

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(children: children),
    );
  }

  // ---- Mahsulot qatori: nom, done/ordered + ingichka progress ----

  Widget _productRow(StatsByProduct p) {
    final progress = p.ordered <= 0
        ? 0.0
        : (p.done / p.ordered).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name.isEmpty ? '#${p.productId}' : p.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${p.done}/${p.ordered}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.done >= p.ordered && p.ordered > 0
                      ? Colors.green.shade700
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1 ? Colors.green : _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Shef qatori ----

  Widget _shefRow(StatsByShef s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 16, color: _accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              s.shefName.isEmpty ? 'Shef #${s.shefId}' : s.shefName,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${s.orders} buyurtma • ${s.piecesDone}/${s.piecesOrdered} dona',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  // ---- Kun qatori: sana + max'ga nisbatan gorizontal bar ----

  Widget _dayRow(StatsByDay d) {
    final maxDone = stats.byDay
        .fold<int>(0, (m, e) => e.piecesDone > m ? e.piecesDone : m);
    final frac =
        maxDone <= 0 ? 0.0 : (d.piecesDone / maxDone).clamp(0.0, 1.0);

    String label = d.date;
    final dt = DateTime.tryParse(d.date);
    if (dt != null) label = DateFormat('dd.MM').format(dt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  // Nol bo'lmasa ham ko'rinishi uchun minimal kenglik.
                  width: d.piecesDone <= 0
                      ? 0
                      : (constraints.maxWidth * frac).clamp(3.0, double.infinity),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${d.piecesDone}',
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Bo'lim tezligi qatori ----

  Widget _stageRow(StatsStageAvg st) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: _accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              st.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${st.avgHours.toStringAsFixed(1)} soat • ${st.count} ta',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
