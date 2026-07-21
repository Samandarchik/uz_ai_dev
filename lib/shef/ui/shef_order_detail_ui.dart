// shef/ui/shef_order_detail_ui.dart — buyurtma tafsiloti ekrani:
// ShefOrderDetailUi — bo'limlar bo'yicha masalliq qabul/rad va done_qty
// kiritish; ShefProvider ustida.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';
import 'package:uz_ai_dev/shef/provider/shef_provider.dart';
import 'package:uz_ai_dev/shef/ui/shef_home_ui.dart';

// Buyurtma tafsiloti: har mahsulot uchun bo'limlar ro'yxati —
// masalliq holati (qabul qildim / qabul qilmadim), done_qty kiritish va
// reja.md §4 dagi hisob-kitob jadvali (boshlanmagan / bo'limlarda / tayyor).
class ShefOrderDetailUi extends StatefulWidget {
  final int orderId;

  const ShefOrderDetailUi({super.key, required this.orderId});

  @override
  State<ShefOrderDetailUi> createState() => _ShefOrderDetailUiState();
}

class _ShefOrderDetailUiState extends State<ShefOrderDetailUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Ochilganda eng yangi holatni olamiz (ro'yxatdagi nusxa eskirgan
      // bo'lishi mumkin).
      context.read<ShefProvider>().refreshOrder(widget.orderId);
    });
  }

  void _snackError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // «Qabul qildim» — masalliqni qabul qilish.
  Future<void> _accept(int pi, int si) async {
    final err = await context
        .read<ShefProvider>()
        .acceptStage(widget.orderId, pi, si);
    if (err != null && mounted) _snackError(err);
  }

  // «Qabul qilmadim» — izoh so'rab rad etish.
  Future<void> _reject(int pi, int si) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (comment == null || !mounted) return;
    final err = await context
        .read<ShefProvider>()
        .rejectStage(widget.orderId, pi, si, comment);
    if (err != null && mounted) _snackError(err);
  }

  // done_qty kiritish (raqam dialogi, qo'shni bo'limlarga qarab tekshiruv).
  Future<void> _editDone(ProductionItem item, int pi, int si) async {
    final stage = item.stages[si];
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _DoneQtyDialog(
        stageName: stage.name,
        current: stage.doneQty,
        maxQty: item.qty,
        prevDone: si > 0 ? item.stages[si - 1].doneQty : null,
        nextDone: si < item.stages.length - 1
            ? item.stages[si + 1].doneQty
            : null,
      ),
    );
    if (value == null || !mounted) return;
    final err = await context
        .read<ShefProvider>()
        .setProgress(widget.orderId, pi, si, value);
    // Server 400 xabari (masalan kamaytirish taqiqlangan) shu yerda chiqadi.
    if (err != null && mounted) _snackError(err);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShefProvider>(
      builder: (context, provider, child) {
        final order = provider.orderById(widget.orderId);

        return Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            title: Text(
              order == null || order.orderId.isEmpty
                  ? 'Buyurtma'
                  : order.orderId,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (order != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(child: productionStatusChip(order.status)),
                ),
            ],
          ),
          body: order == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : RefreshIndicator(
                  onRefresh: () => provider.refreshOrder(widget.orderId),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      if (order.status == ProductionStatus.tayyor)
                        _readyBanner(),
                      for (int pi = 0; pi < order.items.length; pi++)
                        _itemCard(order, order.items[pi], pi,
                            provider.busyStageKey),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // Buyurtma to'liq tayyor bo'lganda yashil banner.
  Widget _readyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buyurtma to\'liq tayyor!',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bitta mahsulot qatori: kengayadigan bo'lim (ichida bo'limlar + hisob).
  Widget _itemCard(
    ProductionOrder order,
    ProductionItem item,
    int pi,
    String? busyKey,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isReady ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: order.items.length == 1,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          '${item.name} — ${item.qty} dona (${item.batches} partiya)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Tayyor: ${item.doneQty}/${item.qty}',
          style: TextStyle(
            fontSize: 12.5,
            color: item.isReady ? Colors.green.shade700 : Colors.grey.shade600,
            fontWeight: item.isReady ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (int si = 0; si < item.stages.length; si++)
            _stageBlock(order, item, pi, si, busyKey),
          if (item.stages.isNotEmpty) _summaryTable(item),
        ],
      ),
    );
  }

  // Bitta bo'lim bloki: nom, masalliq holati, qabul/rad tugmalari, done_qty
  // qatori va yig'ilgan «Masalliqlar» ro'yxati.
  Widget _stageBlock(
    ProductionOrder order,
    ProductionItem item,
    int pi,
    int si,
    String? busyKey,
  ) {
    final stage = item.stages[si];
    final busy = busyKey == ShefProvider.stageKey(order.id, pi, si);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: stage.materialStatus == MaterialStatus.radEtildi
              ? Colors.red.shade300
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${si + 1}. ${stage.name}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _materialChip(stage),
            ],
          ),

          // Rad etilgan bo'lsa izoh ko'rinadi.
          if (stage.materialStatus == MaterialStatus.radEtildi &&
              stage.rejectComment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Izoh: ${stage.rejectComment}',
                style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
              ),
            ),

          // Ombor «Berdim» degan — shef qabul qiladi yoki rad etadi.
          if (stage.materialStatus == MaterialStatus.berildi)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: busy
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _reject(pi, si),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Qabul qilmadim'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _accept(pi, si),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Qabul qildim'),
                          ),
                        ),
                      ],
                    ),
            ),

          // done_qty qatori: joriy qiymat + tahrirlash.
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tugatildi: ${stage.doneQty} / ${item.qty} dona',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: () => _editDone(item, pi, si),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Sonni kiritish',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
              ],
            ),
          ),

          // Masalliqlar — shef uchun ma'lumot sifatida, yig'ilgan holda.
          if (stage.ingredients.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Masalliqlar (${stage.ingredients.length})',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                children: [
                  for (final ing in stage.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          if (!ing.linked)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Tooltip(
                                message: 'Qoldiqqa bog\'lanmagan',
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              ing.name,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            // stock_amount API birlikda (кг/литр -> gr/ml).
                            '${formatQty(ing.stockAmount, ing.stockUnit)} ${ing.stockUnit}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // reja.md §4 jadvali: Boshlanmagan / har bo'limda nechta / To'liq tayyor.
  Widget _summaryTable(ProductionItem item) {
    final stages = item.stages;
    final rows = <MapEntry<String, int>>[
      MapEntry('Boshlanmagan', item.qty - stages.first.doneQty),
      for (int i = 1; i < stages.length; i++)
        MapEntry(
          '$i→${i + 1} kutmoqda (${stages[i].name})',
          stages[i - 1].doneQty - stages[i].doneQty,
        ),
      MapEntry('To\'liq tayyor', stages.last.doneQty),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].key,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: i == rows.length - 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: i == rows.length - 1
                            ? Colors.green.shade700
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '${rows[i].value} ta',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: i == rows.length - 1
                          ? Colors.green.shade700
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Masalliq holati chipi.
  Widget _materialChip(ProductionStage stage) {
    final String label;
    final Color color;
    switch (stage.materialStatus) {
      case MaterialStatus.berildi:
        label = 'Berildi';
        color = Colors.blue.shade700;
        break;
      case MaterialStatus.qabulQilindi:
        label = 'Qabul qilindi';
        color = Colors.green.shade700;
        break;
      case MaterialStatus.radEtildi:
        label = 'Rad etildi';
        color = Colors.red.shade700;
        break;
      default:
        label = 'Berilmagan';
        color = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

}

// Rad etish izohi dialogi.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Qabul qilmadim'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Izoh (nima yetishmadi?)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Rad etish'),
        ),
      ],
    );
  }
}

// done_qty kiritish dialogi. Mijoz tomonda tekshiruvlar:
// 0..maxQty oralig'i, oldingi bo'limdan oshmaslik, keyingi bo'limdan kam
// bo'lmaslik. Server 400 xabari chaqiruvchida snackbar bilan chiqadi.
class _DoneQtyDialog extends StatefulWidget {
  final String stageName;
  final int current;
  final int maxQty;
  final int? prevDone; // oldingi bo'lim soni (birinchi bo'limda null)
  final int? nextDone; // keyingi bo'lim soni (oxirgi bo'limda null)

  const _DoneQtyDialog({
    required this.stageName,
    required this.current,
    required this.maxQty,
    this.prevDone,
    this.nextDone,
  });

  @override
  State<_DoneQtyDialog> createState() => _DoneQtyDialogState();
}

class _DoneQtyDialogState extends State<_DoneQtyDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null) {
      setState(() => _error = 'Son kiriting');
      return;
    }
    if (v < 0 || v > widget.maxQty) {
      setState(() => _error = '0 dan ${widget.maxQty} gacha bo\'lishi kerak');
      return;
    }
    if (widget.prevDone != null && v > widget.prevDone!) {
      setState(() => _error =
          'Oldingi bo\'lim sonidan (${widget.prevDone}) oshmasligi kerak');
      return;
    }
    if (widget.nextDone != null && v < widget.nextDone!) {
      setState(() => _error =
          'Keyingi bo\'lim sonidan (${widget.nextDone}) kam bo\'lmasligi kerak');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.stageName} — tugatilgan son',
        style: const TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Necha dona tugatildi (jami)',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Maksimum: ${widget.prevDone ?? widget.maxQty} '
            '(son kumulyativ — jami tugatilgan dona kiritiladi)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
