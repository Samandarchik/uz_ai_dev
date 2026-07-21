// admin/ui/pos_sales_ui.dart — Konak POS smena sotuvlari ekrani (faqat admin):
// PosSalesUi (StatefulWidget) — PosSaleService bilan smena sotuv hisobotlari
// va umumiy summani ko'rsatadi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/pos_sale_model.dart';
import 'package:uz_ai_dev/admin/services/pos_sale_service.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart'
    show fmtCostMoney;

// POS sotuvlari — Konak POS smena yopilganda mone'ga yuboradigan sotuv
// hisobotlari. GET /api/pos-sales?days=30 (faqat admin). Tepada umumiy
// summa, ro'yxatda har smena kartasi — ochilganda mahsulotlar.
//
// MUHIM (gram kontrakt): qty API'da saqlanadigan birlikda BUTUN
// (кг/л -> gr/ml) — formatQtyUnit kg/l ga qaytaradi. Pul — butun so'm.

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);

// "YYYY-MM-DD" -> "dd.MM.yyyy" (o'qib bo'lmasa xom holida).
String _fmtSaleDate(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null ? date : DateFormat('dd.MM.yyyy').format(parsed);
}

class PosSalesUi extends StatefulWidget {
  const PosSalesUi({super.key});

  @override
  State<PosSalesUi> createState() => _PosSalesUiState();
}

class _PosSalesUiState extends State<PosSalesUi> {
  final PosSaleService _service = PosSaleService();

  PosSalesResult? _result;
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
      final result = await _service.fetchPosSales();
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
          'POS sotuvlari',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          if (_result != null) _totalHeader(_result!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: _kAccent,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  // Tepadagi umumiy summa (oxirgi 30 kun, ko'rsatilgan yozuvlar yig'indisi).
  Widget _totalHeader(PosSalesResult result) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jami sotuv (oxirgi 30 kun, ${result.sales.length} ta smena)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            '${fmtCostMoney(result.total)} so\'m',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8A6F45),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
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

    final sales = _result?.sales ?? const <PosSale>[];
    if (sales.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hozircha sotuv hisobotlari yo\'q',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sales.length,
      itemBuilder: (context, index) => _saleCard(sales[index]),
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

  // Bitta smena kartasi: sana + filial + smena raqami, jami summa;
  // ochilganda mahsulotlar ro'yxati.
  Widget _saleCard(PosSale sale) {
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
            '${_fmtSaleDate(sale.date)} · ${sale.filialName}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'smena #${sale.shiftId} · ${sale.items.length} ta mahsulot',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          trailing: Text(
            '${fmtCostMoney(sale.total)} so\'m',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8A6F45),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          children: [for (final item in sale.items) _itemRow(item)],
        ),
      ),
    );
  }

  // Mahsulot qatori: nom, miqdor (birlik bilan), summa.
  Widget _itemRow(PosSaleItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatQtyUnit(item.qty, item.unit),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${fmtCostMoney(item.total)} so\'m',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
