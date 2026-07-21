// admin/ui/pos_recons_ui.dart — Konak POS smena solishtiruvi ekrani (faqat
// admin): PosReconsUi (StatefulWidget) — PosReconService bilan har smena
// kutilgan vs fakt qoldiq + kassa farqlarini ko'rsatadi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/pos_recon_model.dart';
import 'package:uz_ai_dev/admin/services/pos_recon_service.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart'
    show fmtCostMoney;

// POS solishtirish — Konak POS smena yopilganda mone'ga yuboradigan qoldiq
// solishtiruvi (kutilgan vs fakt). GET /api/pos-recons?days=30 (faqat admin).
// Har smena kartasi: kassa farqi qatori + mahsulotlar bo'yicha farqlar.
//
// MUHIM (gram kontrakt): miqdorlar API'da saqlanadigan birlikda BUTUN
// (кг/л -> gr/ml) — formatQtyUnit kg/l ga qaytaradi. Pul — butun so'm.

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);
const Color _kBad = Color(0xFFD32F2F); // farq manfiy / kassa farqi — qizil
const Color _kWarn = Color(0xFFEF6C00); // farq musbat — to'q sariq
const Color _kOk = Color(0xFF2E7D32); // farq yo'q — yashil

// "YYYY-MM-DD" -> "dd.MM.yyyy" (o'qib bo'lmasa xom holida).
String _fmtReconDate(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null ? date : DateFormat('dd.MM.yyyy').format(parsed);
}

class PosReconsUi extends StatefulWidget {
  const PosReconsUi({super.key});

  @override
  State<PosReconsUi> createState() => _PosReconsUiState();
}

class _PosReconsUiState extends State<PosReconsUi> {
  final PosReconService _service = PosReconService();

  PosReconsResult? _result;
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
      final result = await _service.fetchPosRecons();
      if (!mounted) return;
      setState(() {
        _result = result;
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

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: const Text(
          'POS solishtirish',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kAccent,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && _result == null) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    final recons = _result?.recons ?? const <PosRecon>[];
    if (recons.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hozircha solishtiruv yozuvlari yo\'q',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: recons.length,
      itemBuilder: (context, index) => _reconCard(recons[index]),
    );
  }

  // Pull-to-refresh xato/bo'sh holatda ham ishlashi uchun skrollanadigan markaz.
  Widget _scrollableCenter({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  // Bitta smena kartasi: sana + filial + smena raqami, holat chipi;
  // ochilganda kassa farqi qatori va mahsulot farqlari.
  Widget _reconCard(PosRecon recon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile'ning default chizig'ini olib tashlash.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            '${_fmtReconDate(recon.date)} · ${recon.filialName}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'smena #${recon.shiftId} · ${recon.items.length} ta mahsulot',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          trailing: recon.isClean
              ? _statusChip('✓ Farq yo\'q', _kOk)
              : _statusChip('${recon.problemCount} ta farq', _kBad),
          children: [
            _cashRow(recon),
            const SizedBox(height: 4),
            for (final item in recon.items) _itemRow(item),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Kassa farqi qatori: 0 -> yashil "farq yo'q", aks holda qizil summa.
  Widget _cashRow(PosRecon recon) {
    final cash = recon.cashDifference;
    final ok = cash == 0;
    final color = ok ? _kOk : _kBad;
    final text = ok
        ? 'Kassa: farq yo\'q'
        : 'Kassa farqi: ${cash > 0 ? '+' : '-'}${fmtCostMoney(cash.abs())} so\'m';
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // Mahsulot qatori: nom, "kutilgan X, fakt Y" va farq badge'i
  // (qizil manfiy / to'q sariq musbat; farq 0 bo'lsa yashil belgicha).
  Widget _itemRow(PosReconItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                Text(
                  'kutilgan ${formatQtyUnit(item.expected, item.unit)}, '
                  'fakt ${formatQtyUnit(item.actual, item.unit)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _diffBadge(item),
        ],
      ),
    );
  }

  Widget _diffBadge(PosReconItem item) {
    if (item.diff == 0) {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.check, size: 16, color: _kOk),
      );
    }
    final color = item.diff < 0 ? _kBad : _kWarn;
    final text = '${item.diff > 0 ? '+' : '-'}'
        '${formatQtyUnit(item.diff.abs(), item.unit)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
