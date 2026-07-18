import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/provider/stock_provider.dart';
import 'package:uz_ai_dev/production/services/stock_service.dart';
import 'package:uz_ai_dev/production/ui/inventory_history_page.dart';

// Inventarizatsiya sahifasi (F5): skladni oyoq bilan aylanib chiqib, HAR bir
// mahsulotni real sanash. Ro'yxatda qoldiq qatorlari ham, hali qoldiq yozuvi
// yo'q katalog mahsulotlari ham (qty 0) bo'ladi — «tizimda 5 ta, aslida
// bormi?» va «umuman yo'q nima?» savollariga javob shu yerda.
//
// Har biriga real sanab chiqilgan sonni kiritish maydoni (bo'sh — o'zgarmaydi,
// hint — joriy qoldiq); kiritilgan zahoti joriy qoldiqqa nisbatan farq
// ko'rsatiladi. Faqat to'ldirilgan qatorlar POST /api/stock/inventory ga
// yuboriladi; farqlar backend'da korreksiya bo'lib yoziladi.
// Ombor (o'z skladi) ham, admin (istalgan sklad tabi) ham shu sahifani ochadi.
//
// MUHIM: qatorlar StockProvider keshidan EMAS, to'g'ridan-to'g'ri servisdan
// (include_all bilan) olinadi. Aks holda qty-0 qatorlar umumiy keshga tushib,
// boshqa ekranlarda («Kam qolganlar», ombor kartalari) «Qoldiq: 0» bo'lib
// ko'rinib ketardi. Saqlash esa StockProvider.submitInventory orqali — u
// yuborgandan keyin keshni o'zi jim yangilaydi.
//
// Ko'rinishi — Excel jadvali (tex karta muharriri bilan bir xil uslub):
// Rasm | ID | Nomi | Dasturda | Skladda | Birlik | Farq.

// ---- Excel uslubi konstantalar (tech_card_editor_page.dart bilan bir xil) ----

const Color _kBorderColor = Color(0xFF333333);
const BorderSide _kSide = BorderSide(color: _kBorderColor, width: 1);
const Color _kHeaderColor = Color(0xFFE0E0E0); // sarlavha qatori
const Color _kLowTint = Color(0xFFFFF8E1); // kam qolgan qator — mayin sariq

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

// Ustun kengliklari: «Nomi» — Expanded, qolgani qat'iy.
const double _kImgColW = 48;
const double _kIdColW = 48;
const double _kQtyColW = 76; // «Dasturda»
const double _kInputColW = 84; // «Skladda» (kiritish maydoni)
const double _kUnitColW = 52; // «Birlik»
const double _kDiffColW = 64; // «Farq»
// Shundan tor ekranda jadval gorizontal skroll bo'ladi (aks holda «Nomi»
// ustuni yanchilib ketardi). Qat'iy ustunlar 372 — «Nomi» ga ~220 qoladi.
const double _kMinTableWidth = 600;
const double _kThumbSize = 40;

class StockInventoryPage extends StatefulWidget {
  final int skladId;

  const StockInventoryPage({super.key, required this.skladId});

  @override
  State<StockInventoryPage> createState() => _StockInventoryPageState();
}

// Ro'yxat filtri: hammasi | hali sanalmagan | farqi chiqqan.
enum _InvFilter { all, uncounted, diff }

class _StockInventoryPageState extends State<StockInventoryPage> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);
  static const Color _diffMinus = Color(0xFFD32F2F);
  static const Color _diffPlus = Color(0xFF2E7D32);
  static const Color _okColor = Color(0xFF7B927E);

  // Qoralama: yozishdan ~700ms keyin saqlanadi (yuk'dagi naqsh).
  static const Duration _draftDebounce = Duration(milliseconds: 700);

  final StockService _service = StockService();
  final BaseStorage _storage = sl<BaseStorage>();

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _InvFilter _filter = _InvFilter.all;

  // product_id -> kiritish controlleri (qator ro'yxati o'zgarsa ham saqlanadi).
  final Map<int, TextEditingController> _controllers = {};

  // Sahifaning O'Z ro'yxati (provider keshi emas) — include_all bilan.
  List<StockRow>? _rows;
  bool _loading = false;
  String? _error;

  bool _submitting = false;

  Timer? _draftTimer;
  bool _draftRestored = false;

  String get _draftKey => 'stock_inventory_draft_${widget.skladId}';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _load();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _searchController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── Ma'lumot yuklash ─────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // include_all: qoldiq yozuvi yo'q mahsulotlar ham (qty 0) keladi.
      final rows = await _service.fetchStock(widget.skladId, includeAll: true);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  // ───────────────────────── Qoralama (local) ─────────────────────────

  // {"<product_id>": "<kiritilgan matn>"} — matn ko'rinishida saqlanadi,
  // shunda yarim yozilgan qiymat ham aynan tiklanadi.
  void _persistDraft() {
    final out = <String, String>{};
    _controllers.forEach((productId, ctrl) {
      final raw = ctrl.text.trim();
      if (raw.isEmpty) return;
      out['$productId'] = raw;
    });
    if (out.isEmpty) {
      _storage.remove(key: _draftKey);
      return;
    }
    _storage.putString(key: _draftKey, value: jsonEncode(out));
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(_draftDebounce, () {
      _draftTimer = null;
      _persistDraft();
    });
  }

  void _restoreDraft() {
    final raw = _storage.getString(key: _draftKey);
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        final productId = int.tryParse(key.toString());
        if (productId == null) return;
        final text = value?.toString() ?? '';
        if (text.isEmpty) return;
        _controllerFor(productId).text = text;
        _draftRestored = true;
      });
    } catch (_) {
      // Buzuq JSON — e'tiborsiz qoldiramiz.
    }
  }

  void _clearDraft() {
    _draftTimer?.cancel();
    _draftTimer = null;
    _storage.remove(key: _draftKey);
  }

  // ───────────────────────── Hisob-kitob ─────────────────────────

  TextEditingController _controllerFor(int productId) =>
      _controllers.putIfAbsent(productId, () => TextEditingController());

  // Qatorga kiritilgan son (UI birlikda: kg/l/шт) — bo'sh yoki xato: null.
  double? _inputUi(StockRow row) {
    final ctrl = _controllers[row.productId];
    if (ctrl == null) return null;
    final raw = ctrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value < 0) return null;
    return value;
  }

  // Farq API birligida (гр/мл — gramm kontrakti): kiritilgan − joriy.
  // null — qator sanalmagan.
  double? _diffApi(StockRow row) {
    final ui = _inputUi(row);
    if (ui == null) return null;
    return qtyFromUiSafe(ui, row.type).toDouble() - row.qty;
  }

  bool _hasDiff(StockRow row) {
    final d = _diffApi(row);
    return d != null && d.abs() > 1e-9;
  }

  List<StockRow> get _allRows => _rows ?? const <StockRow>[];

  // Sanalgan (yaroqli son kiritilgan) qatorlar.
  List<StockRow> get _countedRows =>
      _allRows.where((r) => _inputUi(r) != null).toList();

  List<StockRow> get _diffRows => _allRows.where(_hasDiff).toList();

  // Qidiruv + filtr.
  List<StockRow> get _visibleRows {
    final q = _query.toLowerCase().trim();
    return _allRows.where((r) {
      if (q.isNotEmpty && !r.name.toLowerCase().contains(q)) return false;
      switch (_filter) {
        case _InvFilter.all:
          return true;
        case _InvFilter.uncounted:
          return _inputUi(r) == null;
        case _InvFilter.diff:
          return _hasDiff(r);
      }
    }).toList();
  }

  // Farqni UI birlikda ishorali matn: "-2", "+1.5".
  String _diffLabel(StockRow row, double diffApi) {
    final ui = qtyToUi(diffApi, row.type);
    final sign = ui > 0 ? '+' : '-';
    return '$sign${fmtStockQty(ui.abs())}';
  }

  String _rowName(StockRow row) =>
      row.name.isEmpty ? 'Mahsulot #${row.productId}' : row.name;

  // ───────────────────────── Saqlash ─────────────────────────

  Future<void> _confirmAndSubmit() async {
    final counted = _countedRows;
    if (counted.isEmpty || _submitting) return;

    final diffs = _diffRows
      ..sort((a, b) => _diffApi(b)!.abs().compareTo(_diffApi(a)!.abs()));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Inventarizatsiyani saqlash?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${counted.length} ta pozitsiya sanaldi, '
              '${diffs.length} tasida farq bor.',
              style: const TextStyle(fontSize: 13.5),
            ),
            if (diffs.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Farq yo\'q — qoldiqlar o\'zgarmaydi.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Eng katta farqlar:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              // Eng katta 5 tasi — dialog uzayib ketmasligi uchun.
              for (final row in diffs.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_rowName(row)}: '
                    '${formatQty(row.qty, row.type)} → '
                    '${fmtStockQty(_inputUi(row)!)} '
                    '(${_diffLabel(row, _diffApi(row)!)})',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _diffApi(row)! < 0 ? _diffMinus : _diffPlus,
                    ),
                  ),
                ),
              if (diffs.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'va yana ${diffs.length - 5} ta...',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    await _submit(counted);
  }

  Future<void> _submit(List<StockRow> counted) async {
    setState(() => _submitting = true);
    final provider = context.read<StockProvider>();

    // Maydonlarda UI birlik (kg/l) — API'ga butun gramm/ml yuboriladi.
    num toApi(StockRow row, double ui) {
      final api = qtyFromUiSafe(ui, row.type);
      return api % 1 == 0 ? api.toInt() : api;
    }

    final (changed, err) = await provider.submitInventory(
      skladId: widget.skladId,
      items: [
        for (final row in counted)
          {
            'product_id': row.productId,
            'actual_qty': toApi(row, _inputUi(row)!),
          },
      ],
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    // Muvaffaqiyatda qoralama endi keraksiz.
    if (err == null) _clearDraft();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '${changed ?? 0} ta korreksiya'),
        backgroundColor: err == null ? Colors.green : Colors.red,
      ),
    );
    if (err == null) Navigator.pop(context);
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          'Inventarizatsiya — ${productionSkladName(widget.skladId)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Oldingi sanashlar (dalolatnomalar): qachon, nima kam chiqqan,
          // qancha pul.
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InventoryHistoryPage(skladId: widget.skladId),
              ),
            ),
            icon: const Icon(Icons.history),
            tooltip: 'Inventarizatsiya tarixi',
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Builder(
            builder: (context) {
              final count = _countedRows.length;
              return ElevatedButton.icon(
                onPressed:
                    count == 0 || _submitting ? null : _confirmAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fact_check_outlined, size: 20),
                label: Text('Saqlash ($count ta o\'zgaradi)'),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _rows == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && _rows == null) {
      return Center(
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

    if (_allRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Inventarizatsiya qilinadigan mahsulot topilmadi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final visible = _visibleRows;

    return Column(
      children: [
        if (_draftRestored) _draftBanner(),
        // Ko'rsatma + hisob + qidiruv + filtrlar.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Real sanab chiqilgan sonlarni kiriting. Bo\'sh qoldirilgan '
                'qatorlar o\'zgarmaydi.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              _summary(),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Mahsulot qidirish...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear, color: Colors.grey),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _filterChips(),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _filter == _InvFilter.uncounted
                          ? 'Hamma pozitsiya sanaldi.'
                          : _filter == _InvFilter.diff
                              ? 'Farqli pozitsiya yo\'q.'
                              : 'Mahsulot topilmadi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : _excelTable(visible),
        ),
      ],
    );
  }

  // Qoralama tiklandi — yopib qo'yish mumkin bo'lgan eslatma.
  Widget _draftBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: Color(0xFFB26A00)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Saqlanmagan qoralama tiklandi',
              style: TextStyle(fontSize: 12, color: Color(0xFFB26A00)),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _draftRestored = false),
            icon: const Icon(Icons.close, size: 16, color: Color(0xFFB26A00)),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            tooltip: 'Yopish',
          ),
        ],
      ),
    );
  }

  // Sanaldi: 12/45  |  Farq: 3 ta
  Widget _summary() {
    final counted = _countedRows.length;
    final total = _allRows.length;
    final diff = _diffRows.length;

    return Row(
      children: [
        _summaryChip(
          icon: Icons.checklist_rtl,
          label: 'Sanaldi: $counted/$total',
          color: counted == total ? _diffPlus : Colors.grey.shade700,
        ),
        const SizedBox(width: 8),
        _summaryChip(
          icon: Icons.compare_arrows,
          label: 'Farq: $diff ta',
          color: diff > 0 ? _diffMinus : Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    Widget chip(_InvFilter value, String label) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _filter = value),
          backgroundColor: Colors.white,
          selectedColor: _accent,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
          side: BorderSide(color: selected ? _accent : Colors.grey.shade300),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(_InvFilter.all, 'Hammasi'),
          chip(_InvFilter.uncounted, 'Sanalmagan'),
          chip(_InvFilter.diff, 'Farqli'),
        ],
      ),
    );
  }

  // ───────────────────────── Excel jadvali ─────────────────────────

  // Jadval: qat'iy sarlavha qatori + ostida vertikal skroll qatorlar.
  // Tor ekranda (telefon) butun jadval gorizontal skrollga o'raladi, shunda
  // «Nomi» ustuni yanchilmaydi va kataklar ustunma-ustun tekis turadi.
  Widget _excelTable(List<StockRow> rows) {
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
                  itemCount: rows.length,
                  itemBuilder: (context, index) => _tableRow(rows[index]),
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

  // Bitta katak. width null — Expanded («Nomi»). first — chap chegarasiz
  // (tashqi ramka beradi), qolganlarida chap chegara ustunlarni ajratadi.
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

  // Sarlavha: Rasm | ID | Nomi | Dasturda | Skladda | Birlik | Farq
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
            head('Rasm', width: _kImgColW, first: true),
            head('ID', width: _kIdColW),
            head('Nomi', a: Alignment.centerLeft),
            head('Dasturda', width: _kQtyColW),
            head('Skladda', width: _kInputColW),
            head('Birlik', width: _kUnitColW),
            head('Farq', width: _kDiffColW),
          ],
        ),
      ),
    );
  }

  // Bitta jadval qatori. Kam qolgan (low) qator mayin sariq fonda — to'r
  // ko'rinishini buzmaydi, lekin ko'zga tashlanadi.
  Widget _tableRow(StockRow row) {
    final ctrl = _controllerFor(row.productId);
    final diffApi = _diffApi(row);

    return Container(
      decoration: BoxDecoration(
        color: row.low ? _kLowTint : Colors.white,
        border: const Border(left: _kSide, right: _kSide, bottom: _kSide),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rasm — bosilsa katta ko'rinishda ochiladi.
            _cell(
              width: _kImgColW,
              first: true,
              padding: const EdgeInsets.all(4),
              child: _thumb(row),
            ),
            // ID — mayin, tabular.
            _cell(
              width: _kIdColW,
              child: Text(
                '${row.productId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Nomi — 2 qatorgacha.
            _cell(
              align: Alignment.centerLeft,
              child: Text(
                _rowName(row),
                style: _kCellStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Dasturda — tizimdagi qoldiq (UI birlikda), manfiy bo'lsa qizil.
            _cell(
              width: _kQtyColW,
              align: Alignment.centerRight,
              child: Text(
                formatQty(row.qty, row.type),
                style: row.qty < 0
                    ? const TextStyle(
                        fontSize: 13,
                        color: _diffMinus,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      )
                    : _kNumStyle,
              ),
            ),
            // Skladda — real sanalgan son (qoralama shu yerda yashaydi).
            _cell(
              width: _kInputColW,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _countField(row, ctrl),
            ),
            // Birlik — kiritish maydonining yonida, alohida ustun.
            _cell(
              width: _kUnitColW,
              child: Text(row.type, style: _kCellStyle),
            ),
            // Farq — jonli: -2 qizil, +1 yashil, teng bo'lsa ✓.
            _cell(
              width: _kDiffColW,
              align: Alignment.centerRight,
              child: _diffCell(row, diffApi),
            ),
          ],
        ),
      ),
    );
  }

  // «Rasm» katagi: 40x40 thumbnail; yo'q/xato — kulrang placeholder.
  Widget _thumb(StockRow row) {
    if (row.imageUrl.isEmpty) return _thumbPlaceholder();
    return InkWell(
      onTap: () => _showImageDialog(row),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CachedNetworkImage(
          imageUrl: '${AppUrls.baseUrl}${row.imageUrl}',
          width: _kThumbSize,
          height: _kThumbSize,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: _kThumbSize,
            height: _kThumbSize,
            color: Colors.grey.shade200,
          ),
          errorWidget: (_, __, ___) => _thumbPlaceholder(),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: _kThumbSize,
      height: _kThumbSize,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: Colors.grey.shade500,
      ),
    );
  }

  // Rasm bosilsa to'liq ko'rinishda (ombor kartalaridagi naqsh).
  void _showImageDialog(StockRow row) {
    if (row.imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: CachedNetworkImage(
          imageUrl: '${AppUrls.baseUrl}${row.imageUrl}',
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: _accent),
          ),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.error, size: 40, color: Colors.white),
        ),
      ),
    );
  }

  // «Skladda» katagi — real sanalgan sonni kiritish maydoni. Birlik endi o'z
  // ustunida, shuning uchun maydon ichida suffiks yo'q; hint — tizimdagi son.
  Widget _countField(StockRow row, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      textAlign: TextAlign.right,
      style: _kNumStyle,
      decoration: InputDecoration(
        // Hint UI birlikda — foydalanuvchi ham kg/l kiritadi.
        hintText: formatQty(row.qty, row.type),
        hintStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: _accent, width: 1.4),
        ),
      ),
      // Farq/hisob/tugma matni yangilanishi uchun + qoralama.
      onChanged: (_) {
        setState(() {});
        _scheduleDraftSave();
      },
    );
  }

  // «Farq» katagi: sanalmagan — bo'sh; teng — mayin ✓; aks holda ±son.
  Widget _diffCell(StockRow row, double? diffApi) {
    if (diffApi == null) return const SizedBox.shrink();
    if (diffApi.abs() <= 1e-9) {
      return const Text(
        '✓',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _okColor,
        ),
      );
    }
    return Text(
      _diffLabel(row, diffApi),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: diffApi < 0 ? _diffMinus : _diffPlus,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
