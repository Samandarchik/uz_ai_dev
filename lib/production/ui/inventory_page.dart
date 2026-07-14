import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/provider/stock_provider.dart';

// Inventarizatsiya sahifasi (F5): skladning BARCHA qoldiq qatorlari, har
// biriga real sanab chiqilgan sonni kiritish maydoni (bo'sh — o'zgarmaydi,
// hint — joriy qoldiq). Faqat to'ldirilgan qatorlar POST /api/stock/inventory
// ga yuboriladi; farqlar backend'da korreksiya bo'lib yoziladi.
// Ombor (o'z skladi) ham, admin (istalgan sklad tabi) ham shu sahifani ochadi.
class StockInventoryPage extends StatefulWidget {
  final int skladId;

  const StockInventoryPage({super.key, required this.skladId});

  @override
  State<StockInventoryPage> createState() => _StockInventoryPageState();
}

class _StockInventoryPageState extends State<StockInventoryPage> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // product_id -> kiritish controlleri (qator ro'yxati o'zgarsa ham saqlanadi).
  final Map<int, TextEditingController> _controllers = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<StockProvider>();
      if (provider.stockFor(widget.skladId) == null &&
          !provider.isLoading(widget.skladId)) {
        provider.fetchStock(widget.skladId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int productId) =>
      _controllers.putIfAbsent(productId, () => TextEditingController());

  // To'ldirilgan (yaroqli son kiritilgan) qatorlar: product_id -> actual_qty.
  Map<int, double> _filledValues() {
    final result = <int, double>{};
    _controllers.forEach((productId, ctrl) {
      final raw = ctrl.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) return;
      final value = double.tryParse(raw);
      if (value == null || value < 0) return;
      result[productId] = value;
    });
    return result;
  }

  Future<void> _submit() async {
    final filled = _filledValues();
    if (filled.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final provider = context.read<StockProvider>();
    // Maydonlarda UI birlik (kg/l) — API'ga butun gramm/ml yuboriladi.
    final typeById = <int, String>{
      for (final r in provider.stockFor(widget.skladId) ?? const <StockRow>[])
        r.productId: r.type,
    };
    num toApi(int productId, double v) {
      final api = qtyFromUi(v, typeById[productId]);
      return api % 1 == 0 ? api.toInt() : api;
    }

    final (changed, err) = await provider.submitInventory(
      skladId: widget.skladId,
      items: [
        for (final e in filled.entries)
          {'product_id': e.key, 'actual_qty': toApi(e.key, e.value)},
      ],
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '${changed ?? 0} ta korreksiya'),
        backgroundColor: err == null ? Colors.green : Colors.red,
      ),
    );
    if (err == null) Navigator.pop(context);
  }

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
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          final rows = provider.stockFor(widget.skladId);
          final loading = provider.isLoading(widget.skladId);
          final error = provider.errorFor(widget.skladId);

          if (loading && rows == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (error != null && rows == null) {
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
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchStock(widget.skladId),
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

          final all = rows ?? const <StockRow>[];
          final q = _query.toLowerCase().trim();
          final filtered = q.isEmpty
              ? all
              : all.where((r) => r.name.toLowerCase().contains(q)).toList();

          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Qoldiq yozuvlari yo\'q — inventarizatsiya qilinadigan '
                  'mahsulot topilmadi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }

          return Column(
            children: [
              // Ko'rsatma + qidiruv.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Real sanab chiqilgan sonlarni kiriting. Bo\'sh '
                      'qoldirilgan qatorlar o\'zgarmaydi.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Mahsulot qidirish...',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.clear,
                                    color: Colors.grey),
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
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _inventoryRow(filtered[index]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Builder(
            builder: (context) {
              final count = _filledValues().length;
              return ElevatedButton.icon(
                onPressed: count == 0 || _submitting ? null : _submit,
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

  // Bitta qator: nomi + joriy qoldiq | real son kiritish maydoni.
  Widget _inventoryRow(StockRow row) {
    final ctrl = _controllerFor(row.productId);
    final filled = ctrl.text.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: filled ? _accent : Colors.grey.shade300,
          width: filled ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name.isEmpty ? 'Mahsulot #${row.productId}' : row.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Joriy: ${formatQty(row.qty, row.type)} ${row.type}'.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          row.qty < 0 ? Colors.red : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  // Hint UI birlikda — foydalanuvchi ham kg/l kiritadi.
                  hintText: formatQty(row.qty, row.type),
                  suffixText: row.type.isNotEmpty ? row.type : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Tugma matnidagi hisoblagich yangilanishi uchun.
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
