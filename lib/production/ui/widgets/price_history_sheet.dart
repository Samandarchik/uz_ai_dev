import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/models/price_history_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart';

// Bitta masalliqning xarid narxlari tarixi bottom sheet'i —
// GET /api/prices/history. Tex karta muharriridagi «Цена» katagi bosilganda
// ochiladi. Qator: «dd.MM.yyyy • sklad • pricer — qty birlik × 1kg narxi = summa».

const Color _accent = Color(0xFFC5A97B);

void showPriceHistorySheet(
  BuildContext context, {
  required int productId,
  String productName = '',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) =>
        _PriceHistorySheet(productId: productId, productName: productName),
  );
}

class _PriceHistorySheet extends StatefulWidget {
  final int productId;
  final String productName;

  const _PriceHistorySheet({required this.productId, this.productName = ''});

  @override
  State<_PriceHistorySheet> createState() => _PriceHistorySheetState();
}

class _PriceHistorySheetState extends State<_PriceHistorySheet> {
  late Future<List<PriceHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ProductionService().fetchPriceHistory(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.productName.isEmpty
                          ? 'Narx tarixi'
                          : 'Narx tarixi — ${widget.productName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<PriceHistoryEntry>>(
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
                            Text(
                              snapshot.error
                                  .toString()
                                  .replaceFirst('Exception: ', ''),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _future = ProductionService()
                                    .fetchPriceHistory(widget.productId);
                              }),
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
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text(
                        'Tarix yo\'q',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _HistoryRow(entry: entries[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final PriceHistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date == null
        ? '—'
        : DateFormat('dd.MM.yyyy').format(entry.date!.toLocal());
    final head = [
      date,
      if (entry.skladName.isNotEmpty) entry.skladName,
      if (entry.pricer.isNotEmpty) entry.pricer,
    ].join(' • ');
    // qty eng kichik birlikda -> UI'da kg/l; narx eng kichik birlik uchun ->
    // UI'da 1 kg/l narxi (x qtyUnitFactor).
    final detail = '${formatQty(entry.qty, entry.unit)} ${entry.unit} × '
        '${fmtCostMoney(entry.price * qtyUnitFactor(entry.unit))} = '
        '${fmtCostMoney(entry.sum)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            head,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
