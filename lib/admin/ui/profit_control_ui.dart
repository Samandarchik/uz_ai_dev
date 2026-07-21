import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/model/tech_card_cost.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/ui/profit_analytics_ui.dart';
import 'package:uz_ai_dev/admin/ui/tech_card_editor_page.dart';
import 'package:uz_ai_dev/core/data/local/base_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/production/models/latest_price_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart';

// «Foyda nazorati» — tex kartasi bor barcha mahsulotlarning marjasi bitta
// jadvalda: Mahsulot | Tannarx (C) | Narx (sale_price) | Foyda %.
// Eng yomon marja tepada. Chegaradan (default 20%) past qatorlar qizil.
// Tavsiya narxi saqlanganidan farq qilsa «→ X» tugmasi chiqadi — bosish
// admin tasdig'i: tex kartadagi sale_price yangilanib saqlanadi.
// Hisob-kitob TO'LIQ mijoz tomonida — tech_card_cost.dart helperlari bilan.

const String _kThresholdKey = 'profit_control_threshold';
const int _kDefaultThreshold = 20;

class ProfitControlUi extends StatefulWidget {
  const ProfitControlUi({super.key});

  @override
  State<ProfitControlUi> createState() => _ProfitControlUiState();
}

// Bitta jadval qatori uchun hisoblangan qiymatlar.
class _RowData {
  final ProductModelAdmin product;
  final TechCard card;
  final double fullCost; // C (1 dona to'liq tannarx), 0 — noma'lum
  final double? margin; // null — hisoblab bo'lmaydi
  final int? suggested; // tavsiya narxi (null — foyda belgilanmagan/C yo'q)

  const _RowData({
    required this.product,
    required this.card,
    required this.fullCost,
    required this.margin,
    required this.suggested,
  });
}

class _ProfitControlUiState extends State<ProfitControlUi> {
  final BaseStorage _storage = sl<BaseStorage>();
  final TextEditingController _thresholdCtrl = TextEditingController();

  Map<int, LatestPrice> _prices = {};
  bool _loading = true;
  String? _error;
  int _threshold = _kDefaultThreshold;

  // Hozir narxi saqlanayotgan mahsulot id'lari (qator tugmasida spinner).
  final Set<int> _savingIds = {};

  @override
  void initState() {
    super.initState();
    final saved = int.tryParse(_storage.getString(key: _kThresholdKey));
    _threshold = saved ?? _kDefaultThreshold;
    _thresholdCtrl.text = _threshold.toString();
    _load();
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<ProductProviderAdmin>();
      // Ikkalasi parallel: mahsulotlar (provider) + oxirgi narxlar.
      final pricesFuture = ProductionService().fetchLatestPrices();
      await provider.initializeProducts(forceRefresh: force);
      final prices = await pricesFuture;
      if (!mounted) return;
      setState(() {
        _prices = prices;
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

  void _onThresholdChanged(String text) {
    final v = int.tryParse(text.trim());
    setState(() => _threshold = v ?? _kDefaultThreshold);
    if (v != null) {
      _storage.putString(key: _kThresholdKey, value: v.toString());
    }
  }

  // «→ X» tugmasi: admin tasdig'i — tex kartadagi sale_price ni tavsiyaga
  // almashtirib saqlaymiz (provider ro'yxatni lokal yangilaydi).
  Future<void> _applySuggested(_RowData row) async {
    final suggested = row.suggested;
    if (suggested == null || _savingIds.contains(row.product.id)) return;
    setState(() => _savingIds.add(row.product.id));

    final provider = context.read<ProductProviderAdmin>();
    final updated = row.product.copyWith(
      techCard: row.card.copyWith(salePrice: suggested),
    );
    final ok = await provider.updateProduct(updated);

    if (!mounted) return;
    setState(() => _savingIds.remove(row.product.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${row.product.name}: narx ${fmtCostMoney(suggested)} qilib saqlandi'
              : provider.error ?? 'Saqlashda xatolik',
        ),
        backgroundColor: ok ? null : Colors.red,
      ),
    );
  }

  // Mahsulotlardan jadval qatorlarini yig'ish.
  List<_RowData> _buildRows(List<ProductModelAdmin> products) {
    final wasteFactors = techWasteFactors(products);
    // Полуфабрикат qatorlari rekursiv tannarx bilan hisoblanadi.
    final byId = techProductsById(products);
    final rows = <_RowData>[];
    for (final p in products) {
      // Полуфабрикат sotilmaydi — «Foyda nazorati» ro'yxatiga kirmaydi.
      if (p.isSemiFinished) continue;
      final card = p.techCard;
      if (!techCardHasContent(card)) continue;
      final c0 =
          techIngredientPieceCost(card!, _prices, wasteFactors, products: byId);
      final full = techFullPieceCost(card.overheadMode, card.overheadValue, c0);
      rows.add(_RowData(
        product: p,
        card: card,
        fullCost: full,
        margin:
            card.salePrice > 0 ? techMarginPercent(card.salePrice, full) : null,
        suggested:
            techSuggestedSalePrice(card.profitMode, card.profitValue, full),
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foyda nazorati'),
        actions: [
          // Davr bo'yicha foyda analitikasi ekrani (marja dinamikasi va h.k.).
          IconButton(
            tooltip: 'Analitika',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfitAnalyticsUi()),
            ),
            icon: const Icon(Icons.insights),
          ),
        ],
      ),
      body: Consumer<ProductProviderAdmin>(
        builder: (context, provider, _) {
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
                    onPressed: () => _load(force: true),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          final rows = _buildRows(provider.products);
          // Narxi va tannarxi ma'lum qatorlar — marja bo'yicha o'sish
          // tartibida (eng yomoni tepada).
          final priced = rows.where((r) => r.margin != null).toList()
            ..sort((a, b) => a.margin!.compareTo(b.margin!));
          // Narx belgilanmagan yoki tannarxi noma'lum — pastdagi kulrang bo'lim.
          final unpriced = rows.where((r) => r.margin == null).toList()
            ..sort((a, b) => a.product.name.compareTo(b.product.name));

          return RefreshIndicator(
            onRefresh: () => _load(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _thresholdField(),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Tex kartasi bor mahsulot topilmadi',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else ...[
                  _headerRow(),
                  const Divider(height: 8),
                  for (final row in priced) _productRow(row),
                  if (unpriced.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Narx belgilanmagan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Divider(height: 8),
                    for (final row in unpriced) _productRow(row, grey: true),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // Chegara maydoni: marjasi shu foizdan past qatorlar qizil belgilanadi.
  Widget _thresholdField() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Minimal foyda chegarasi',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _thresholdCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              isDense: true,
              suffixText: '%',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: _onThresholdChanged,
          ),
        ),
      ],
    );
  }

  Widget _headerRow() {
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text('Mahsulot', style: style)),
          SizedBox(
            width: 78,
            child: Text('Tannarx', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: 78,
            child: Text('Narx', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: 56,
            child: Text('Foyda %', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }

  // Qator bosilsa mahsulotning tex karta sahifasi ochiladi (provider
  // saqlashda o'zi yangilanadi — qaytganda jadval qayta hisoblanadi).
  void _openTechCard(_RowData row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TechCardEditorPage(product: row.product),
      ),
    );
  }

  Widget _productRow(_RowData row, {bool grey = false}) {
    final margin = row.margin;
    final low = !grey && margin != null && margin < _threshold;
    final textColor = grey ? Colors.grey.shade500 : Colors.black87;
    final saving = _savingIds.contains(row.product.id);
    final suggested = row.suggested;
    final showSuggestion = suggested != null && suggested != row.card.salePrice;

    return InkWell(
      onTap: () => _openTechCard(row),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: low ? Colors.red.shade50 : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: low ? Colors.red.shade700 : textColor,
                    ),
                  ),
                ),
                _moneyCell(
                  row.fullCost > 0 ? fmtCostMoney(row.fullCost) : '—',
                  width: 78,
                  color: textColor,
                ),
                _moneyCell(
                  row.card.salePrice > 0
                      ? fmtCostMoney(row.card.salePrice)
                      : '—',
                  width: 78,
                  color: textColor,
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    margin == null ? '—' : '${margin.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: low
                          ? Colors.red.shade700
                          : (grey ? Colors.grey.shade500 : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
            // Tavsiya narxi saqlanganidan farq qilsa — «→ X» (Almashtirish).
            if (showSuggestion)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: saving
                      ? const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Tooltip(
                          message: 'Almashtirish',
                          child: InkWell(
                            onTap: () => _applySuggested(row),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                border:
                                    Border.all(color: Colors.orange.shade400),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '→ ${fmtCostMoney(suggested)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _moneyCell(String text, {required double width, Color? color}) {
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12.5, color: color ?? Colors.black87),
        ),
      ),
    );
  }
}
