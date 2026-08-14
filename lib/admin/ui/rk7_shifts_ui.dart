// admin/ui/rk7_shifts_ui.dart — RK7 «Import» tabi (Rk7ShiftsTab) va smena
// detali (Rk7ShiftDetailUi): GET /api/rk7/shifts?days=30 va
// /api/rk7/shifts/{id} — items, voids, unmapped bo'limlari.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart';
import 'package:uz_ai_dev/admin/services/rk7_service.dart';
import 'package:uz_ai_dev/admin/ui/widgets/rk7_common.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/sklad_registry.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart'
    show fmtCostMoney;

// Import logi: RK7 dan tushgan yopilgan smenalar. Har qatorda sana, smena
// raqami, jami summa, yechilgan yozuvlar soni va unmapped badge (>0 — qizil).
// Qatorga bosilsa to'liq detal ekrani ochiladi.
//
// MUHIM: qty_milli — milli-porsiya (butun), ko'rsatishda formatPortions;
// pul — butun so'm (fmtCostMoney).
class Rk7ShiftsTab extends StatefulWidget {
  const Rk7ShiftsTab({super.key});

  @override
  State<Rk7ShiftsTab> createState() => _Rk7ShiftsTabState();
}

class _Rk7ShiftsTabState extends State<Rk7ShiftsTab>
    with AutomaticKeepAliveClientMixin {
  final Rk7Service _service = Rk7Service();

  List<Rk7Shift> _shifts = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchShifts(days: 30);
      if (!mounted) return;
      setState(() {
        _shifts = list;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _load,
      color: kRk7Accent,
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _shifts.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null && _shifts.isEmpty) {
      return rk7ErrorState(_error!, onRetry: _load);
    }
    if (_shifts.isEmpty) {
      return rk7EmptyState(
        Icons.receipt_long,
        'Oxirgi 30 kunda import qilingan smena yo\'q',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _shifts.length,
      itemBuilder: (context, index) => _shiftCard(_shifts[index]),
    );
  }

  // Bitta smena qatori: sana + smena raqami, summa, yechildi/unmapped badge.
  Widget _shiftCard(Rk7Shift shift) {
    final hasUnmapped = shift.unmappedCount > 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Rk7ShiftDetailUi(shift: shift)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${rk7Date(shift.shiftDate)} · smena #${shift.shiftNum}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    '${fmtCostMoney(shift.total)} so\'m',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: kRk7AccentDark,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  rk7Badge('${shift.itemsCount} satr', color: Colors.blueGrey),
                  rk7Badge(
                    'yechildi: ${shift.deductedCount}',
                    color: Colors.green.shade700,
                  ),
                  if (hasUnmapped)
                    rk7Badge(
                      'bog\'lanmagan: ${shift.unmappedCount}',
                      color: Colors.red.shade700,
                    ),
                  if (shift.voidTotal > 0)
                    rk7Badge(
                      'bekor: ${fmtCostMoney(shift.voidTotal)} so\'m',
                      color: Colors.orange.shade800,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Smena detali: items (taom, qty, summa), voids va unmapped bo'limlari.
// Ro'yxatdan kelgan sarlavha darrov ko'rsatiladi, to'liq mazmun
// GET /api/rk7/shifts/{id} dan yuklanadi.
class Rk7ShiftDetailUi extends StatefulWidget {
  const Rk7ShiftDetailUi({super.key, required this.shift});

  final Rk7Shift shift;

  @override
  State<Rk7ShiftDetailUi> createState() => _Rk7ShiftDetailUiState();
}

class _Rk7ShiftDetailUiState extends State<Rk7ShiftDetailUi> {
  final Rk7Service _service = Rk7Service();

  Rk7Shift? _shift;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _service.fetchShift(widget.shift.id);
      if (!mounted) return;
      setState(() {
        _shift = detail ?? widget.shift;
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

  @override
  Widget build(BuildContext context) {
    final head = _shift ?? widget.shift;
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Bg,
        elevation: 0,
        title: Text(
          '${rk7Date(head.shiftDate)} · smena #${head.shiftNum}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: kRk7Accent,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _shift == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null && _shift == null) {
      return rk7ErrorState(_error!, onRetry: _load);
    }
    final shift = _shift ?? widget.shift;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _summary(shift),
        if (shift.unmapped.isNotEmpty) ...[
          _sectionTitle(
            'Bog\'lanmagan taomlar (${shift.unmapped.length})',
            color: Colors.red.shade700,
          ),
          for (final row in shift.unmapped)
            _row(
              row.dishName.isEmpty ? row.dishGuid : row.dishName,
              '${formatPortions(row.qtyMilli)} porsiya',
              null,
            ),
        ],
        _sectionTitle('Sotuvlar (${shift.items.length})'),
        if (shift.items.isEmpty)
          _emptyLine('Satr yo\'q')
        else
          for (final item in shift.items)
            _row(
              item.dishName.isEmpty ? item.dishGuid : item.dishName,
              '${formatPortions(item.qtyMilli)} porsiya',
              '${fmtCostMoney(item.amount)} so\'m',
              subtitle: item.payName.isEmpty ? null : item.payName,
            ),
        _sectionTitle('Bekor qilinganlar (${shift.voids.length})'),
        if (shift.voids.isEmpty)
          _emptyLine('Bekor qilingan satr yo\'q')
        else
          for (final v in shift.voids)
            _row(
              v.dishName.isEmpty ? v.dishGuid : v.dishName,
              '${formatPortions(v.qtyMilli)} porsiya',
              '${fmtCostMoney(v.amount)} so\'m',
            ),
        if (shift.deductions.isNotEmpty) ...[
          _sectionTitle('Skladdan yechildi (${shift.deductions.length})'),
          for (final d in shift.deductions)
            _row(
              d.productName.isEmpty
                  ? 'Mahsulot #${d.productId}'
                  : d.productName,
              '${d.qty}${d.unit.isEmpty ? '' : ' ${d.unit}'}',
              null,
              subtitle: SkladRegistry.nameOf(d.skladId),
            ),
        ],
      ],
    );
  }

  // Sarlavha kartasi: jami summa, bekor summasi, sanoqlar.
  Widget _summary(Rk7Shift shift) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kRk7Accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jami sotuv',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            '${fmtCostMoney(shift.total)} so\'m',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kRk7AccentDark,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              rk7Badge('${shift.items.length} satr', color: Colors.blueGrey),
              rk7Badge(
                'yechildi: ${shift.deductions.length}',
                color: Colors.green.shade700,
              ),
              if (shift.unmapped.isNotEmpty)
                rk7Badge(
                  'bog\'lanmagan: ${shift.unmapped.length}',
                  color: Colors.red.shade700,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _emptyLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
    );
  }

  // Bitta qator: nom (+izoh), miqdor, summa.
  Widget _row(String name, String qty, String? money, {String? subtitle}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              qty,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (money != null) ...[
              const SizedBox(width: 12),
              Text(
                money,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
