import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uz_ai_dev/admin/model/profit_analytics_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart';

// «Foyda analitikasi» — GET /api/analytics/profit?days=N (admin/bugalter).
// Davr bo'yicha KPI kartalar, eng yomon 4 tortning marja dinamikasi chizig'i
// (CustomPaint), minusga o'tgan tortlar, masalliq narx sakrashlari va
// tort bo'yicha foyda ustunlari. Marja HOZIRGI sotish narxi bilan, tannarx —
// o'sha kungi oxirgi kirim narxi bilan hisoblangan (backend hisoblaydi).

// Seriya ranglari — qat'iy tartib (CVD-xavfsiz to'plam, oq fonda tekshirilgan).
const List<Color> _seriesColors = [
  Color(0xFF2A78D6), // ko'k
  Color(0xFF008300), // yashil
  Color(0xFFE87BA4), // pushti
  Color(0xFFEDA100), // sariq
];

class ProfitAnalyticsUi extends StatefulWidget {
  const ProfitAnalyticsUi({super.key});

  @override
  State<ProfitAnalyticsUi> createState() => _ProfitAnalyticsUiState();
}

// Chart uchun bitta seriya: nomi (qisqartirilgan), rangi va days ro'yxatiga
// mos marja qiymatlari (null — o'sha kuni marja hisoblanmagan).
class _ChartSeries {
  final String name;
  final Color color;
  final List<double?> values;
  final double? endValue; // oxirgi ma'lum marja (legend uchun)
  final List<double?> costs; // kunlik 1 dona tannarx (so'm) — tooltip uchun
  final double salePrice; // joriy sotish narxi (foyda so'mda hisoblash uchun)

  const _ChartSeries({
    required this.name,
    required this.color,
    required this.values,
    required this.endValue,
    required this.costs,
    required this.salePrice,
  });
}

// Tayyorlangan chart ma'lumotlari (build ichida yig'iladi).
class _ChartData {
  final List<String> days;
  final List<_ChartSeries> series;
  final double yMin;
  final double yMax;

  const _ChartData({
    required this.days,
    required this.series,
    required this.yMin,
    required this.yMax,
  });
}

class _ProfitAnalyticsUiState extends State<ProfitAnalyticsUi> {
  int _days = 30;
  bool _loading = true;
  String? _error;
  ProfitAnalytics? _data;
  int? _selectedIndex; // chartda tanlangan kun (tooltip paneli)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIndex = null;
    });
    try {
      final data = await ProductionService().fetchProfitAnalytics(_days);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ---------- Format helperlar ----------

  String _ddMM(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd.MM').format(dt);
  }

  String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  // Sotilgan dona: butun bo'lsa 3 xonali guruhlash, aks holda 1 kasr.
  String _fmtQty(double v) =>
      v == v.roundToDouble() ? fmtCostMoney(v) : v.toStringAsFixed(1);

  // «Тортик Рафаэлло 18 дм» -> «Рафаэлло» (legend/tooltip uchun qisqa nom).
  String _shortName(String name) {
    var s = name.trim();
    s = s.replaceFirst(RegExp(r'^\s*Тортик\s*', caseSensitive: false), '');
    s = s.replaceAll(
        RegExp(r'\s*\d+\s*(дм|см|dm|sm)\.?\s*$', caseSensitive: false), '');
    s = s.trim();
    return s.isEmpty ? name : s;
  }

  // ---------- Chart ma'lumotlarini yig'ish ----------

  // Marjasi bor tortlardan margin_end bo'yicha eng yomon 4 tasi.
  _ChartData _buildChart(ProfitAnalytics data) {
    final withMargin = data.cakes.where((c) => c.marginEnd != null).toList()
      ..sort((a, b) => a.marginEnd!.compareTo(b.marginEnd!));
    final worst = withMargin.take(4).toList();

    final series = <_ChartSeries>[];
    for (var i = 0; i < worst.length; i++) {
      final cake = worst[i];
      final byDate = <String, double?>{
        for (final p in cake.daily) p.d: p.margin,
      };
      final costByDate = <String, double?>{
        for (final p in cake.daily) p.d: p.cost,
      };
      final values = [for (final d in data.days) byDate[d]];
      double? end;
      for (final v in values) {
        if (v != null) end = v;
      }
      series.add(_ChartSeries(
        name: _shortName(cake.name),
        color: _seriesColors[i],
        values: values,
        endValue: end,
        costs: [for (final d in data.days) costByDate[d]],
        salePrice: cake.salePrice,
      ));
    }

    // Y oralig'i: 0% va 20% yo'l-yo'riq chiziqlari doim ko'rinadi.
    var lo = 0.0, hi = 20.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v == null) continue;
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    var pad = (hi - lo) * 0.08;
    if (pad <= 0) pad = 5;
    return _ChartData(
      days: data.days,
      series: series,
      yMin: lo - pad,
      yMax: hi + pad,
    );
  }

  // Chartga teginish/surish — eng yaqin kun indeksini tanlash.
  void _selectAt(double dx, double width, int dayCount) {
    if (dayCount == 0) return;
    final w =
        width - _MarginChartPainter.padLeft - _MarginChartPainter.padRight;
    if (w <= 0) return;
    final rel = ((dx - _MarginChartPainter.padLeft) / w).clamp(0.0, 1.0);
    final idx = (rel * (dayCount - 1)).round();
    if (idx != _selectedIndex) setState(() => _selectedIndex = idx);
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foyda analitikasi')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    final data = _data;
    if (data == null) return const SizedBox.shrink();
    final chart = _buildChart(data);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          _periodChips(),
          const SizedBox(height: 10),
          _kpiGrid(data.totals),
          const SizedBox(height: 12),
          _chartCard(chart),
          const SizedBox(height: 12),
          _negativeCard(data),
          const SizedBox(height: 12),
          _eventsCard(data),
          const SizedBox(height: 12),
          _profitBarsCard(data),
          const SizedBox(height: 12),
          Text(
            'Sotuvlar filial buyurtmalaridan olinadi. Marja — hozirgi sotish '
            'narxi bilan, tannarx — o\'sha kungi oxirgi kirim narxi bilan '
            'hisoblangan.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // 1. Davr tanlash chiplari: 7 / 30 / 90 kun.
  Widget _periodChips() {
    return Row(
      children: [
        for (final d in const [7, 30, 90])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$d kun'),
              selected: _days == d,
              onSelected: (sel) {
                if (!sel || _days == d) return;
                setState(() => _days = d);
                _load();
              },
            ),
          ),
      ],
    );
  }

  // 2. KPI kartalar (2x2).
  Widget _kpiGrid(ProfitTotals t) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _kpiCard(
                'Jami foyda',
                '${fmtCostMoney(t.profit)} so\'m',
                valueColor: t.profit < 0 ? Colors.red.shade700 : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiCard(
                'Tushum',
                '${fmtCostMoney(t.revenue)} so\'m',
                sub: '${_fmtQty(t.sold)} dona sotilgan',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _kpiCard(
                'Xarajat (tannarx)',
                '${fmtCostMoney(t.cost)} so\'m',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiCard(
                'Minusga tushgan',
                '${t.negativeCount} tort',
                valueColor: t.negativeCount > 0 ? Colors.red.shade700 : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value,
      {String? sub, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  // Bo'lim kartasi (umumiy o'ram).
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // 3. Marja dinamikasi (chiziqli chart, CustomPaint).
  Widget _chartCard(_ChartData chart) {
    if (chart.series.isEmpty) {
      return _sectionCard(
        icon: Icons.show_chart,
        title: 'Marja dinamikasi',
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Marja ma\'lumotlari yo\'q',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ],
      );
    }

    return _sectionCard(
      icon: Icons.show_chart,
      title: 'Marja dinamikasi (eng yomon ${chart.series.length} tort)',
      children: [
        // Legend chiplar: rang + qisqa nom + oxirgi marja.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final s in chart.series) _legendChip(s)],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: (d) =>
                  _selectAt(d.localPosition.dx, width, chart.days.length),
              onHorizontalDragStart: (d) =>
                  _selectAt(d.localPosition.dx, width, chart.days.length),
              onHorizontalDragUpdate: (d) =>
                  _selectAt(d.localPosition.dx, width, chart.days.length),
              child: SizedBox(
                width: width,
                height: 220,
                child: CustomPaint(
                  painter: _MarginChartPainter(
                    days: chart.days,
                    series: chart.series,
                    yMin: chart.yMin,
                    yMax: chart.yMax,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
            );
          },
        ),
        if (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < chart.days.length)
          _selectedDayPanel(chart, _selectedIndex!),
      ],
    );
  }

  Widget _legendChip(_ChartSeries s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '${s.name} ${_pct(s.endValue)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Tanlangan kun paneli (chart tooltip'i): sana + har seriya uchun
  // o'sha kungi tannarx (so'm), 1 dona foyda (so'm) va marja (%).
  Widget _selectedDayPanel(_ChartData chart, int idx) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _ddMM(chart.days[idx]),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'tannarx • 1 dona foyda • marja',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final s in chart.series)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  Text(
                    s.costs[idx] == null ? '—' : fmtCostMoney(s.costs[idx]!),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _dayProfitText(s, idx),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: (s.values[idx] ?? 0) < 0
                          ? Colors.red.shade700
                          : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // «+48 336 • +40,6%» — 1 dona foyda (sotish narxi − o'sha kungi tannarx)
  // va marja. Tannarx/narx noma'lum bo'lsa faqat mavjud qismi.
  String _dayProfitText(_ChartSeries s, int idx) {
    final cost = s.costs[idx];
    final margin = s.values[idx];
    if (cost == null || s.salePrice <= 0) return _pct(margin);
    final profit = s.salePrice - cost;
    final sign = profit >= 0 ? '+' : '−';
    return '$sign${fmtCostMoney(profit.abs())} • ${_pct(margin)}';
  }

  // 4. «Qachon minusga o'tdi» kartasi.
  Widget _negativeCard(ProfitAnalytics data) {
    final negatives = data.cakes.where((c) => c.negative != null).toList()
      ..sort((a, b) => a.negative!.compareTo(b.negative!));

    return _sectionCard(
      icon: Icons.trending_down,
      title: 'Qachon minusga o\'tdi',
      children: [
        if (negatives.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bu davrda minusga tushgan tort yo\'q ✅',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          )
        else
          for (final c in negatives)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ddMM(c.negative!),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_pct(c.marginStart)} → ${_pct(c.marginEnd)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  // 5. «Narx sakrashlari» kartasi (masalliq kirim narxlari, ≥5%).
  Widget _eventsCard(ProfitAnalytics data) {
    return _sectionCard(
      icon: Icons.price_change_outlined,
      title: 'Narx sakrashlari',
      children: [
        if (data.events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bu davrda sezilarli narx o\'zgarishi yo\'q',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          )
        else
          for (final e in data.events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // Narxlar eng kichik birlik (1 gr/ml) uchun —
                          // 1 kg/l narxi sifatida x1000 ko'rsatamiz.
                          '${_ddMM(e.date)} • '
                          '${fmtCostMoney(e.oldPrice * 1000)} → '
                          '${fmtCostMoney(e.newPrice * 1000)} so\'m',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _changeChip(e.changePct),
                ],
              ),
            ),
      ],
    );
  }

  Widget _changeChip(double pct) {
    final up = pct >= 0; // oshgan — qimmatlashdi (yomon), qizil
    final color = up ? Colors.red : Colors.green;
    final text =
        '${up ? '+' : ''}${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: up ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: up ? color.shade300 : color.shade400),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: up ? color.shade700 : color.shade800,
        ),
      ),
    );
  }

  // 6. «Tort bo'yicha foyda» — gorizontal ustunlar.
  Widget _profitBarsCard(ProfitAnalytics data) {
    final priced = data.cakes.where((c) => c.salePrice > 0).toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));
    final unpriced = data.cakes.where((c) => c.salePrice <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    var maxAbs = 0.0;
    for (final c in priced) {
      maxAbs = math.max(maxAbs, c.profit.abs());
    }
    if (maxAbs <= 0) maxAbs = 1;

    return _sectionCard(
      icon: Icons.bar_chart,
      title: 'Tort bo\'yicha foyda',
      children: [
        if (priced.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Narxlangan tort yo\'q',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          )
        else
          for (final c in priced) _profitBarRow(c, maxAbs),
        if (unpriced.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Narx belgilanmagan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const Divider(height: 10),
          for (final c in unpriced)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
        ],
      ],
    );
  }

  Widget _profitBarRow(ProfitCake c, double maxAbs) {
    final negative = c.profit < 0;
    final frac = (c.profit.abs() / maxAbs).clamp(0.02, 1.0).toDouble();
    return InkWell(
      onTap: () => _showCakeSales(c),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: frac,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        negative ? Colors.red.shade600 : Colors.green.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Sotilgan dona — foyda summasidan oldin.
            SizedBox(
              width: 52,
              child: Text(
                '${c.sold == c.sold.roundToDouble() ? c.sold.toInt() : c.sold} ta',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 86,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  fmtCostMoney(c.profit),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: negative ? Colors.red.shade700 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tort bosilganda: kunlik sotuvlar ro'yxati (qachon • nechta • nechpuldan •
  // kun foydasi) pastdan oynada. Sotuvsiz kunlar ko'rsatilmaydi.
  void _showCakeSales(ProfitCake c) {
    final days = c.daily.where((p) => p.qty > 0).toList().reversed.toList();
    final hasPrice = c.salePrice > 0;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollCtrl) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPrice
                        ? 'Sotish narxi: ${fmtCostMoney(c.salePrice)} so\'m • '
                            'Jami: ${_qtyText(c.sold)} ta • '
                            'foyda ${fmtCostMoney(c.profit)} so\'m'
                        : 'Jami: ${_qtyText(c.sold)} ta (narx belgilanmagan)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: days.isEmpty
                  ? const Center(
                      child: Text(
                        'Bu davrda sotuv bo\'lmagan',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: days.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, i) {
                        final p = days[i];
                        final dayProfit =
                            hasPrice ? p.qty * (c.salePrice - p.cost) : null;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 46,
                                child: Text(
                                  _ddMM(p.d),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 46,
                                child: Text(
                                  '${_qtyText(p.qty)} ta',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  hasPrice
                                      ? '× ${fmtCostMoney(c.salePrice)}'
                                      : '',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 92,
                                child: Text(
                                  dayProfit == null
                                      ? '—'
                                      : '${dayProfit < 0 ? '−' : '+'}'
                                          '${fmtCostMoney(dayProfit.abs())}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                    color: (dayProfit ?? 0) < 0
                                        ? Colors.red.shade700
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Butun son bo'lsa kasrsiz (5), aks holda qisqa kasr (2.5).
  static String _qtyText(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

// ---------------------------------------------------------------------------
// Marja dinamikasi chizig'i — CustomPaint (paketsiz).
// Y — marja %, yo'l-yo'riq chiziqlar: 20% (punktir, to'q sariq) va 0% (yaxlit).
// X — davr kunlari, bir nechta dd.MM belgisi. null qiymatda chiziq uziladi.
// ---------------------------------------------------------------------------
class _MarginChartPainter extends CustomPainter {
  static const double padLeft = 38;
  static const double padRight = 10;
  static const double padTop = 8;
  static const double padBottom = 20;

  final List<String> days;
  final List<_ChartSeries> series;
  final double yMin;
  final double yMax;
  final int? selectedIndex;

  _MarginChartPainter({
    required this.days,
    required this.series,
    required this.yMin,
    required this.yMax,
    this.selectedIndex,
  });

  double _x(Size size, int i) {
    final w = size.width - padLeft - padRight;
    if (days.length <= 1) return padLeft + w / 2;
    return padLeft + w * i / (days.length - 1);
  }

  double _y(Size size, double v) {
    final h = size.height - padTop - padBottom;
    final range = (yMax - yMin) == 0 ? 1 : (yMax - yMin);
    return padTop + h * (1 - (v - yMin) / range);
  }

  void _text(
    Canvas canvas,
    String s,
    Offset anchor,
    TextStyle style, {
    Alignment align = Alignment.centerLeft,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = anchor.dx - (align.x + 1) / 2 * tp.width;
    final dy = anchor.dy - (align.y + 1) / 2 * tp.height;
    tp.paint(canvas, Offset(dx, dy));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 5, double gap = 4}) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = math.min(t + dash, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey.shade600);
    final left = padLeft;
    final right = size.width - padRight;

    // Chegara (yengil ramka o'rnida pastki o'q chizig'i).
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(left, size.height - padBottom),
      Offset(right, size.height - padBottom),
      axisPaint,
    );

    // Y chetki qiymatlar (0/20 bilan ustma-ust tushmasa).
    void yLabel(double v) {
      _text(
        canvas,
        '${v.round()}%',
        Offset(left - 4, _y(size, v)),
        labelStyle,
        align: Alignment.centerRight,
      );
    }

    final zeroY = _y(size, 0);
    final twentyY = _y(size, 20);
    if ((_y(size, yMax) - twentyY).abs() > 12 &&
        (_y(size, yMax) - zeroY).abs() > 12) {
      yLabel(yMax);
    }
    if ((_y(size, yMin) - zeroY).abs() > 12 &&
        (_y(size, yMin) - twentyY).abs() > 12) {
      yLabel(yMin);
    }

    // 0% — yaxlit chiziq (minus chegarasi).
    if (0 >= yMin && 0 <= yMax) {
      final p = Paint()
        ..color = Colors.grey.shade600
        ..strokeWidth = 1;
      canvas.drawLine(Offset(left, zeroY), Offset(right, zeroY), p);
      yLabel(0);
    }

    // 20% — punktir to'q sariq (minimal foyda chegarasi).
    if (20 >= yMin && 20 <= yMax) {
      final p = Paint()
        ..color = Colors.orange.shade700
        ..strokeWidth = 1;
      _dashedLine(canvas, Offset(left, twentyY), Offset(right, twentyY), p);
      _text(
        canvas,
        '20%',
        Offset(left - 4, twentyY),
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade800,
        ),
        align: Alignment.centerRight,
      );
    }

    // X belgilar: ~4 ta sana (dd.MM).
    final n = days.length;
    if (n > 0) {
      final ticks = <int>{};
      for (var i = 0; i < 4; i++) {
        ticks.add(((n - 1) * i / 3).round());
      }
      for (final i in ticks) {
        final raw = days[i];
        final dt = DateTime.tryParse(raw);
        final label = dt == null ? raw : DateFormat('dd.MM').format(dt);
        var align = Alignment.topCenter;
        if (i == 0) align = Alignment.topLeft;
        if (i == n - 1) align = Alignment.topRight;
        _text(
          canvas,
          label,
          Offset(_x(size, i), size.height - padBottom + 4),
          labelStyle,
          align: align,
        );
      }
    }

    // Seriya chiziqlari (null'da uziladi; yakka nuqta — doiracha).
    for (final s in series) {
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final dotPaint = Paint()..color = s.color;

      Path? path;
      int? lastIdx;
      for (var i = 0; i < s.values.length && i < n; i++) {
        final v = s.values[i];
        if (v == null) {
          if (path != null) canvas.drawPath(path, linePaint);
          path = null;
          continue;
        }
        final p = Offset(_x(size, i), _y(size, v));
        if (path == null) {
          path = Path()..moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
        // Ikkala qo'shnisi null bo'lgan yakka nuqta ko'rinsin.
        final prevNull = i == 0 || s.values[i - 1] == null;
        final nextNull = i == s.values.length - 1 || s.values[i + 1] == null;
        if (prevNull && nextNull) canvas.drawCircle(p, 2.5, dotPaint);
        lastIdx = i;
      }
      if (path != null) canvas.drawPath(path, linePaint);

      // Oxirgi ma'lum nuqtada doiracha (seriya oxiri).
      if (lastIdx != null) {
        final v = s.values[lastIdx]!;
        canvas.drawCircle(Offset(_x(size, lastIdx), _y(size, v)), 3, dotPaint);
      }
    }

    // Tanlangan kun: vertikal chiziq + har seriyada oq halqali nuqta.
    final sel = selectedIndex;
    if (sel != null && sel >= 0 && sel < n) {
      final x = _x(size, sel);
      final selPaint = Paint()
        ..color = Colors.grey.shade500
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, padTop),
        Offset(x, size.height - padBottom),
        selPaint,
      );
      for (final s in series) {
        final v = sel < s.values.length ? s.values[sel] : null;
        if (v == null) continue;
        final p = Offset(x, _y(size, v));
        canvas.drawCircle(p, 5, Paint()..color = Colors.white);
        canvas.drawCircle(p, 3.5, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_MarginChartPainter old) {
    return old.days != days ||
        old.series != series ||
        old.yMin != yMin ||
        old.yMax != yMax ||
        old.selectedIndex != selectedIndex;
  }
}
