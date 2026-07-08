import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/production/models/production_cost_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';

// Tannarx bottom sheet'i (F3) — tex karta tahriri va admin ishlab chiqarish
// tafsiloti bitta shu vidjetni qayta ishlatadi. GET /api/production/cost
// natijasi: 1 dona / 1 partiya tannarxi + masalliqlar jadvali.

const Color _accent = Color(0xFFC5A97B);

// Pul summasi: har 3 xonadan keyin probel (1 500 000) — loyihadagi naqsh.
String fmtCostMoney(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

// Miqdorni chiroyli ko'rsatish: 7.0 -> "7", 7.25 -> "7.25".
String _fmtAmount(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

// Tannarx sheet'ini ochish. productName — sarlavha uchun (javob kelguncha).
void showProductionCostSheet(
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
    builder: (_) => _CostSheet(productId: productId, productName: productName),
  );
}

class _CostSheet extends StatefulWidget {
  final int productId;
  final String productName;

  const _CostSheet({required this.productId, this.productName = ''});

  @override
  State<_CostSheet> createState() => _CostSheetState();
}

class _CostSheetState extends State<_CostSheet> {
  late Future<ProductionCost> _future;

  @override
  void initState() {
    super.initState();
    _future = ProductionService().fetchCost(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 20, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.productName.isEmpty
                          ? 'Tannarx'
                          : 'Tannarx — ${widget.productName}',
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
              child: FutureBuilder<ProductionCost>(
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
                                    .fetchCost(widget.productId);
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
                  final cost = snapshot.data!;
                  return _CostBody(cost: cost);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostBody extends StatelessWidget {
  final ProductionCost cost;

  const _CostBody({required this.cost});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Sarlavha: 1 dona / 1 partiya tannarxi.
        Container(
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
                '1 dona tannarxi: ${fmtCostMoney(cost.pieceCost)} so\'m',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Partiya (${cost.batchQty} ta): '
                '${fmtCostMoney(cost.batchCost)} so\'m',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Masalliqlar jadvali: nomi | miqdor birlik | narx | summa.
        if (cost.items.isNotEmpty) ...[
          _headerRow(),
          const Divider(height: 10),
          for (final item in cost.items) _CostItemRow(item: item),
        ] else
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Masalliqlar yo\'q (tex karta bo\'sh)',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),

        // Footer: narxi yo'q masalliqlar ogohlantirishi.
        if (cost.missing > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${cost.missing} ta masalliqning narxi yo\'q — '
                    'tannarx to\'liq emas',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _headerRow() {
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );
    return Row(
      children: [
        Expanded(flex: 5, child: Text('Masalliq', style: style)),
        Expanded(
          flex: 3,
          child: Text('Miqdor', textAlign: TextAlign.right, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text('Narx', textAlign: TextAlign.right, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text('Summa', textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}

class _CostItemRow extends StatelessWidget {
  final ProductionCostItem item;

  const _CostItemRow({required this.item});

  String _lastPriced(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd.MM.yyyy').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final grey = !item.hasPrice;
    final textColor = grey ? Colors.grey.shade500 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(fontSize: 12.5, color: textColor),
                ),
                if (grey)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'narx yo\'q',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                else if (item.lastPriced.isNotEmpty)
                  Text(
                    _lastPriced(item.lastPriced),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${_fmtAmount(item.amount)} ${item.stockUnit}'.trim(),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, color: textColor),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              grey ? '—' : fmtCostMoney(item.unitPrice),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, color: textColor),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              grey ? '—' : fmtCostMoney(item.cost),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
