// production/ui/inventory_history_page.dart — инвентаризация tarixi (акт'lar)
// ekrani: InventoryHistoryPage + _InventoryActDetailPage (Excel to'r), narxlar
// sanash paytidagi snapshot; StockService.fetchInventories/fetchInventory.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/models/inventory_act_model.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/services/stock_service.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart';

// Inventarizatsiya tarixi (dalolatnomalar) — «16.07 da sanaganda 450 000 so'm
// kam chiqdi: qaysi mahsulot, nechta, qanday narxda?» degan savolga javob.
//
// Ikki ekran:
//   InventoryHistoryPage — dalolatnomalar ro'yxati (eng yangisi birinchi),
//     har birida sana, kim sanagan, nechta pozitsiya va PUL natijasi.
//   _InventoryActDetailPage — bitta dalolatnomaning farqli qatorlari,
//     inventarizatsiya jadvalidagi kabi Excel to'ri bilan.
//
// MUHIM: narxlar sanash paytida suratga olingan (bugungi narx emas) — shuning
// uchun eski dalolatnoma bugun ochilganda ham o'sha kungi pulni ko'rsatadi.

// ---- Excel uslubi konstantalar (inventory_page.dart bilan bir xil) ----

const Color _kBorderColor = Color(0xFF333333);
const BorderSide _kSide = BorderSide(color: _kBorderColor, width: 1);
const Color _kHeaderColor = Color(0xFFE0E0E0);

const EdgeInsets _kCellPad = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
const TextStyle _kCellStyle = TextStyle(fontSize: 13, color: Colors.black);
const TextStyle _kCellBold = TextStyle(
  fontSize: 13,
  color: Colors.black,
  fontWeight: FontWeight.bold,
);
// Raqam kataklari — ustunlar bo'ylab tekis turishi uchun tabular figures.
const TextStyle _kNumStyle = TextStyle(
  fontSize: 13,
  color: Colors.black,
  fontFeatures: [FontFeature.tabularFigures()],
);

// Ustun kengliklari: «Mahsulot» — Expanded, qolgani qat'iy.
const double _kSysColW = 88; // «Tizimda»
const double _kActColW = 88; // «Sanaldi»
const double _kDiffColW = 88; // «Farq»
const double _kPriceColW = 84; // «Narx»
const double _kSumColW = 96; // «Summa»
// Shundan tor ekranda jadval gorizontal skroll bo'ladi (inventory_page dagi
// naqsh). Qat'iy ustunlar 444 — «Mahsulot» ga ~216 qoladi.
const double _kMinTableWidth = 660;

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);
const Color _kMinus = Color(0xFFD32F2F); // kamomad / manfiy
const Color _kPlus = Color(0xFF2E7D32); // ortiqcha / musbat

String _fmtDate(DateTime? dt) =>
    dt == null ? '—' : DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());

// ───────────────────────── Ro'yxat ekrani ─────────────────────────

class InventoryHistoryPage extends StatefulWidget {
  final int skladId;

  const InventoryHistoryPage({super.key, required this.skladId});

  @override
  State<InventoryHistoryPage> createState() => _InventoryHistoryPageState();
}

class _InventoryHistoryPageState extends State<InventoryHistoryPage> {
  final StockService _service = StockService();

  List<InventoryAct>? _acts;
  bool _loading = false;
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
      final acts = await _service.fetchInventories(widget.skladId);
      if (!mounted) return;
      setState(() {
        _acts = acts;
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

  void _openDetail(InventoryAct act) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _InventoryActDetailPage(act: act)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: const Text(
          'Inventarizatsiya tarixi',
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
    if (_loading && _acts == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    // Xato — backend hali tayyor bo'lmasa ham ekran yiqilmaydi, qayta
    // urinish tugmasi chiqadi.
    if (_error != null && _acts == null) {
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

    final acts = _acts ?? const <InventoryAct>[];
    if (acts.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hali inventarizatsiya qilinmagan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: acts.length,
      itemBuilder: (context, index) => _actCard(acts[index]),
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

  // Bitta dalolatnoma kartasi: sana + kim, sanaldi/farq, va pul natijasi.
  Widget _actCard(InventoryAct act) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () => _openDetail(act),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(act.created),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (act.userName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        act.userName,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Sanaldi: ${act.countedItems} · Farq: ${act.diffItems}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _moneyLine(act),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // Pul natijasi: kamomad (qizil) va/yoki ortiqcha (yashil); ikkalasi ham
  // 0 bo'lsa — mayin «Farq yo'q ✅».
  Widget _moneyLine(InventoryAct act) {
    if (act.noMoneyDiff) {
      return Text(
        'Farq yo\'q ✅',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        if (act.shortageTotal > 0)
          Text(
            'Kamomad: ${fmtCostMoney(act.shortageTotal)} so\'m',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: _kMinus,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        if (act.surplusTotal > 0)
          Text(
            'Ortiqcha: +${fmtCostMoney(act.surplusTotal)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _kPlus,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Tafsilot ekrani ─────────────────────────

// Ro'yxatdagi dalolatnoma items'siz keladi — bu ekran ochilganda
// /api/stock/inventories/{id} dan to'liq holatini oladi. Ro'yxatdan kelgan
// nusxa sarlavhani darhol chizish uchun ishlatiladi (spinner ostida ham
// «qaysi sana» ko'rinib turadi).
class _InventoryActDetailPage extends StatefulWidget {
  final InventoryAct act;

  const _InventoryActDetailPage({required this.act});

  @override
  State<_InventoryActDetailPage> createState() =>
      _InventoryActDetailPageState();
}

class _InventoryActDetailPageState extends State<_InventoryActDetailPage> {
  final StockService _service = StockService();

  late InventoryAct _act = widget.act;
  bool _loading = false;
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
      final full = await _service.fetchInventory(widget.act.id);
      if (!mounted) return;
      setState(() {
        _act = full;
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

  String _skladName(InventoryAct act) => act.skladName.isNotEmpty
      ? act.skladName
      : productionSkladName(act.skladId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: const Text(
          'Dalolatnoma',
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
    if (_loading && _act.items.isEmpty && _error == null) {
      return Column(
        children: [
          _header(),
          const Expanded(
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ],
      );
    }

    if (_error != null && _act.items.isEmpty) {
      return Column(
        children: [
          _header(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
              ),
            ),
          ),
        ],
      );
    }

    final items = _act.items;
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _header(),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Farqli pozitsiya yo\'q — hamma qoldiq to\'g\'ri chiqqan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    // Narxlanmagan qator bo'lsa — jadval ostida sabab izohi.
    final hasUnpriced = items.any((i) => i.unitPrice == 0);

    return Column(
      children: [
        _header(),
        Expanded(child: _excelTable(items, hasUnpriced)),
      ],
    );
  }

  // Sarlavha: sana / kim / sklad + kamomad va ortiqcha jamlari.
  Widget _header() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fmtDate(_act.created),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              _skladName(_act),
              if (_act.userName.isNotEmpty) _act.userName,
            ].join(' · '),
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 3),
          Text(
            'Sanaldi: ${_act.countedItems} · Farq: ${_act.diffItems}',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          if (_act.noMoneyDiff)
            Text(
              'Farq yo\'q ✅',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            )
          else
            Row(
              children: [
                if (_act.shortageTotal > 0)
                  _totalChip(
                    label: 'Kamomad',
                    value: '${fmtCostMoney(_act.shortageTotal)} so\'m',
                    color: _kMinus,
                  ),
                if (_act.shortageTotal > 0 && _act.surplusTotal > 0)
                  const SizedBox(width: 8),
                if (_act.surplusTotal > 0)
                  _totalChip(
                    label: 'Ortiqcha',
                    value: '+${fmtCostMoney(_act.surplusTotal)} so\'m',
                    color: _kPlus,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _totalChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Excel jadvali ─────────────────────────

  // Qat'iy sarlavha qatori + ostida vertikal skroll qatorlar; tor ekranda
  // butun jadval gorizontal skrollga o'raladi (inventory_page dagi naqsh).
  Widget _excelTable(List<InventoryActItem> items, bool hasUnpriced) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double hPad = 12;
        final available = constraints.maxWidth - hPad * 2;
        final scrollX = available < _kMinTableWidth;
        final tableWidth = scrollX ? _kMinTableWidth : available;

        final table = SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length + (hasUnpriced ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= items.length) return _unpricedNote();
                    return _tableRow(items[index]);
                  },
                ),
              ),
            ],
          ),
        );

        if (!scrollX) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: hPad),
            child: table,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: hPad),
          child: table,
        );
      },
    );
  }

  // Narxsiz qatorlar bor — «—» nima uchun turganini tushuntiradi.
  Widget _unpricedNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Narx yo\'q — summa hisoblanmagan',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  // Bitta katak. width null — Expanded («Mahsulot»). first — chap chegarasiz
  // (tashqi ramka beradi).
  Widget _cell({
    required Widget child,
    double? width,
    bool first = false,
    Alignment align = Alignment.center,
    EdgeInsets padding = _kCellPad,
  }) {
    final content = Container(
      alignment: align,
      padding: padding,
      decoration: BoxDecoration(
        border: first ? null : const Border(left: _kSide),
      ),
      child: child,
    );
    if (width == null) return Expanded(child: content);
    return SizedBox(width: width, child: content);
  }

  // Sarlavha: Mahsulot | Tizimda | Sanaldi | Farq | Narx | Summa
  Widget _headerRow() {
    Widget head(String text, {double? width, bool first = false, Alignment? a}) =>
        _cell(
          width: width,
          first: first,
          align: a ?? Alignment.center,
          child: Text(text, style: _kCellBold, textAlign: TextAlign.center),
        );

    return Container(
      decoration: const BoxDecoration(
        color: _kHeaderColor,
        border: Border(top: _kSide, left: _kSide, right: _kSide, bottom: _kSide),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head('Mahsulot', first: true, a: Alignment.centerLeft),
            head('Tizimda', width: _kSysColW),
            head('Sanaldi', width: _kActColW),
            head('Farq', width: _kDiffColW),
            head('Narx', width: _kPriceColW),
            head('Summa', width: _kSumColW),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(InventoryActItem item) {
    final name = item.name.isEmpty ? 'Mahsulot #${item.productId}' : item.name;
    // unit_price 0 — o'sha paytda xarid narxi yo'q edi: pul ustunlari «—».
    final priced = item.unitPrice > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: _kSide, right: _kSide, bottom: _kSide),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cell(
              first: true,
              align: Alignment.centerLeft,
              child: Text(
                name,
                style: _kCellStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Tizimda / Sanaldi — gramm kontrakti: formatQty + birlik.
            _cell(
              width: _kSysColW,
              align: Alignment.centerRight,
              child: Text(
                formatQtyUnit(item.systemQty, item.type),
                style: _kNumStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _cell(
              width: _kActColW,
              align: Alignment.centerRight,
              child: Text(
                formatQtyUnit(item.actualQty, item.type),
                style: _kNumStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Farq — manfiy qizil (kamomad), musbat yashil (ortiqcha).
            _cell(
              width: _kDiffColW,
              align: Alignment.centerRight,
              child: Text(
                _diffLabel(item),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: item.diff < 0 ? _kMinus : _kPlus,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Narx — 1 кг/л/шт/м uchun, sanash paytidagi holatda.
            _cell(
              width: _kPriceColW,
              align: Alignment.centerRight,
              child: Text(
                priced ? fmtCostMoney(item.unitPrice) : '—',
                style: priced
                    ? _kNumStyle
                    : TextStyle(fontSize: 13, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Summa — farqning pul qiymati.
            _cell(
              width: _kSumColW,
              align: Alignment.centerRight,
              child: Text(
                priced ? _amountLabel(item) : '—',
                style: priced
                    ? TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.amount < 0 ? _kMinus : _kPlus,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )
                    : TextStyle(fontSize: 13, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Farq ishorali, UI birlikda: "-2 кг", "+1.5 л".
  String _diffLabel(InventoryActItem item) {
    final sign = item.diff < 0 ? '-' : '+';
    return '$sign${formatQtyUnit(item.diff.abs(), item.type)}';
  }

  // Summa ishorali: "-24 000", "+3 000".
  String _amountLabel(InventoryActItem item) {
    final sign = item.amount < 0 ? '-' : '+';
    return '$sign${fmtCostMoney(item.amount.abs())}';
  }
}
