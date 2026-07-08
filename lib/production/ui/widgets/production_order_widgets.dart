import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';
import 'package:uz_ai_dev/shef/ui/shef_home_ui.dart' show productionStatusChip;

// Ishlab chiqarish buyurtmalari uchun UMUMIY vidjetlar — ombor, admin va
// bugalter sahifalari shularni qayta ishlatadi (shef ekranlari o'z
// vidjetlariga ega, faqat status chip umumiy).

const Color kProductionAccent = Color(0xFFC5A97B);
const Color kProductionBg = Color(0xFFFAF6F1);

String _formatDate(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
}

// Masalliq holati chipi (Berilmagan / Berildi / Qabul qilindi / Rad etildi).
Widget materialStatusChip(String status) {
  final String label;
  final Color color;
  switch (status) {
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

// Ro'yxatdagi bitta buyurtma kartasi: order_id, status chip, sana,
// (ixtiyoriy) shef/sklad nomi, mahsulotlar qisqacha va progress.
class ProductionOrderCard extends StatelessWidget {
  final ProductionOrder order;
  final bool showShef;
  final bool showSklad;
  final VoidCallback onTap;

  const ProductionOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showShef = true,
    this.showSklad = false,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (order.progress * 100).round();
    final itemsSummary = order.items
        .map((i) => '${i.name} — ${i.qty} dona (${i.batches} partiya)')
        .join(', ');

    final infoParts = <String>[
      if (showSklad)
        order.skladName.isNotEmpty
            ? order.skladName
            : productionSkladName(order.skladId),
      if (showShef && order.shefName.isNotEmpty) 'Shef: ${order.shefName}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderId.isEmpty ? '№${order.id}' : order.orderId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  productionStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(order.created),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (infoParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: kProductionAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        infoParts.join(' • '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kProductionAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: order.progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          order.status == ProductionStatus.tayyor
                              ? Colors.green
                              : kProductionAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$percent%  (${order.totalDone}/${order.totalQty})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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

// Buyurtma tafsiloti tanasi (ListView): sarlavha ma'lumot kartasi + har
// mahsulot uchun bo'limlar. Ombor stockQtyOf + stageAction beradi («Berdim»
// va qoldiq ustuni), admin faqat stockQtyOf (read-only), bugalter — hech biri.
class ProductionOrderDetailBody extends StatelessWidget {
  final ProductionOrder order;

  // Mahsulot qoldig'i (buyurtma skladida). null funksiya — qoldiq ustuni
  // ko'rsatilmaydi; null natija — qoldiq yozuvi yo'q (0 deb qaraladi).
  final double? Function(int productId)? stockQtyOf;

  // Bo'lim ostidagi amal vidjeti (masalan ombor «Berdim» tugmasi).
  final Widget? Function(ProductionItem item, int pi, int si)? stageAction;

  // Mahsulot kartasi ichidagi (bo'limlardan oldin) qo'shimcha amal —
  // masalan admin «Tannarx» havolasi.
  final Widget? Function(ProductionItem item)? itemAction;

  const ProductionOrderDetailBody({
    super.key,
    required this.order,
    this.stockQtyOf,
    this.stageAction,
    this.itemAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (order.status == ProductionStatus.tayyor) _readyBanner(),
        _headerCard(),
        for (int pi = 0; pi < order.items.length; pi++)
          _ItemCard(
            order: order,
            item: order.items[pi],
            pi: pi,
            stockQtyOf: stockQtyOf,
            stageAction: stageAction,
            itemAction: itemAction,
          ),
      ],
    );
  }

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

  // Sarlavha ma'lumotlari: sana, sklad, shef.
  Widget _headerCard() {
    final skladName = order.skladName.isNotEmpty
        ? order.skladName
        : productionSkladName(order.skladId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _infoRow(Icons.calendar_today_outlined, 'Sana',
              _formatDate(order.created)),
          const SizedBox(height: 6),
          _infoRow(Icons.store_outlined, 'Sklad', skladName),
          if (order.shefName.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.person_outline, 'Shef', order.shefName),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kProductionAccent),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// Bitta mahsulot qatori: kengayadigan karta, ichida bo'limlar.
class _ItemCard extends StatelessWidget {
  final ProductionOrder order;
  final ProductionItem item;
  final int pi;
  final double? Function(int productId)? stockQtyOf;
  final Widget? Function(ProductionItem item, int pi, int si)? stageAction;
  final Widget? Function(ProductionItem item)? itemAction;

  const _ItemCard({
    required this.order,
    required this.item,
    required this.pi,
    this.stockQtyOf,
    this.stageAction,
    this.itemAction,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? extra = itemAction?.call(item);
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
          if (extra != null)
            Align(alignment: Alignment.centerRight, child: extra),
          for (int si = 0; si < item.stages.length; si++)
            _StageBlock(
              item: item,
              pi: pi,
              si: si,
              stockQtyOf: stockQtyOf,
              action: stageAction?.call(item, pi, si),
            ),
        ],
      ),
    );
  }
}

// Bitta bo'lim bloki: nom + masalliq holati chipi, rad izohi, masalliqlar
// jadvali (nomi | kerak | qoldiq | yetadimi) va done_qty (read-only).
class _StageBlock extends StatelessWidget {
  final ProductionItem item;
  final int pi;
  final int si;
  final double? Function(int productId)? stockQtyOf;
  final Widget? action;

  const _StageBlock({
    required this.item,
    required this.pi,
    required this.si,
    this.stockQtyOf,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final stage = item.stages[si];
    final rejected = stage.materialStatus == MaterialStatus.radEtildi;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rejected ? Colors.red.shade50 : kProductionBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rejected ? Colors.red.shade300 : Colors.grey.shade300,
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
              materialStatusChip(stage.materialStatus),
            ],
          ),

          // Berilgan vaqti (bo'lsa) — kichik ma'lumot.
          if (stage.issuedAt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Berilgan: ${_formatDate(stage.issuedAt)}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ),

          // Rad etilgan bo'lsa izoh qizil ko'rinadi.
          if (rejected && stage.rejectComment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Izoh: ${stage.rejectComment}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ),

          // Masalliqlar jadvali.
          if (stage.ingredients.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ingredientsTable(stage),
          ],

          // Bo'lim progressi — bu ekranlarda faqat o'qish uchun (kichik).
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tugatildi: ${stage.doneQty} / ${item.qty} dona',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),

          // Amal (masalan ombor «Berdim»).
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: action!,
            ),
        ],
      ),
    );
  }

  Widget _ingredientsTable(ProductionStage stage) {
    final showStock = stockQtyOf != null;
    final headerStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 5, child: Text('Masalliq', style: headerStyle)),
              Expanded(
                flex: 3,
                child: Text('Kerak',
                    textAlign: TextAlign.right, style: headerStyle),
              ),
              if (showStock)
                Expanded(
                  flex: 3,
                  child: Text('Qoldiq',
                      textAlign: TextAlign.right, style: headerStyle),
                ),
              const SizedBox(width: 26),
            ],
          ),
          const Divider(height: 10),
          for (final ing in stage.ingredients) _ingredientRow(ing, showStock),
        ],
      ),
    );
  }

  Widget _ingredientRow(ProductionIngredient ing, bool showStock) {
    final double? qoldiq = ing.linked ? stockQtyOf?.call(ing.productId) : null;
    final bool short =
        ing.linked && showStock && (qoldiq ?? 0) < ing.stockAmount;

    // Holat belgisi: bog'lanmagan — sariq ⚠; yetmaydi — qizil ⚠; yetadi — ✓.
    final Widget statusIcon;
    if (!ing.linked) {
      statusIcon = const Tooltip(
        message: 'Qoldiqqa bog\'lanmagan',
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(Icons.warning_amber_rounded,
            size: 18, color: Colors.orange),
      );
    } else if (!showStock) {
      statusIcon = const SizedBox.shrink();
    } else if (short) {
      statusIcon = const Tooltip(
        message: 'Qoldiq yetmaydi',
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
      );
    } else {
      statusIcon =
          const Icon(Icons.check_circle, size: 18, color: Colors.green);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              ing.name,
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${fmtStockQty(ing.stockAmount)} ${ing.stockUnit}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showStock)
            Expanded(
              flex: 3,
              child: Text(
                !ing.linked
                    ? '—'
                    : '${fmtStockQty(qoldiq ?? 0)} ${ing.stockUnit}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: !ing.linked
                      ? Colors.grey
                      : (short ? Colors.red : Colors.black87),
                ),
              ),
            ),
          SizedBox(width: 26, child: Center(child: statusIcon)),
        ],
      ),
    );
  }
}

// Bo'limdagi yetishmaydigan masalliqlar ro'yxati («Berdim» dialogi uchun):
// linked bo'lib qoldiq kerakdan kam bo'lganlar.
List<ProductionIngredient> shortIngredients(
  ProductionStage stage,
  double? Function(int productId) stockQtyOf,
) {
  return [
    for (final ing in stage.ingredients)
      if (ing.linked && (stockQtyOf(ing.productId) ?? 0) < ing.stockAmount)
        ing,
  ];
}
