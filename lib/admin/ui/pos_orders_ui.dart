// admin/ui/pos_orders_ui.dart — Konak POS avto-buyurtmalari ekrani (faqat
// admin): PosOrdersUi (StatefulWidget) — PosOrderService bilan buyurtmalarni
// ko'rsatadi va «bazadan yuboradi» (dispatch), qabul/kamomad holatini rangda.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/pos_order_model.dart';
import 'package:uz_ai_dev/admin/services/pos_order_service.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart'
    show fmtCostMoney;

// POS buyurtmalari — Konak POS'dagi «POS avto» useri yaratgan avto-buyurtmalar
// (kechqurun limit kamomadi bo'yicha). Admin bu yerdan buyurtmani «bazadan
// yuboradi» (dispatch) — POS tomonda esa mahsulotlar bitta-bitta qabul
// qilinadi. GET /api/pos-orders, POST /api/pos-orders/{id}/dispatch.
//
// Status: delivery yo'q — «Yuborilmagan» (kulrang), delivery "sent" —
// «Yuborilgan» (ko'k), "completed" — «Qabul qilingan» (yashil). Kamomad
// (accepted < sent) qizil ko'rsatiladi.
//
// MUHIM (gram kontrakt): miqdorlar API'da saqlanadigan birlikda BUTUN
// (кг/л -> gr/ml) — formatQtyUnit kg/l ga qaytaradi. Pul — butun so'm.

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);
const Color _kShortfall = Color(0xFFD32F2F); // kamomad — qizil
const Color _kAccepted = Color(0xFF2E7D32); // to'liq qabul — yashil
const Color _kSent = Color(0xFF1565C0); // yuborilgan — ko'k

String _fmtDate(DateTime? dt) =>
    dt == null ? '—' : DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());

class PosOrdersUi extends StatefulWidget {
  const PosOrdersUi({super.key});

  @override
  State<PosOrdersUi> createState() => _PosOrdersUiState();
}

class _PosOrdersUiState extends State<PosOrdersUi> {
  final PosOrderService _service = PosOrderService();

  List<PosOrder>? _orders;
  bool _loading = true;
  String? _error;
  // Hozir dispatch so'rovi ketayotgan buyurtmalar (tugma bloklanadi).
  final Set<int> _dispatching = {};

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
      final orders = await _service.fetchPosOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  // «Bazadan yuborish» — tasdiqlash dialogi, so'ng POST dispatch.
  // Muvaffaqiyatda javobdagi delivery bilan JOYIDA yangilanadi
  // (to'liq re-fetch YO'Q).
  Future<void> _dispatch(PosOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Bazadan yuborish',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '#${order.orderId} — ${order.filialName}\n'
          '${order.items.length} ta mahsulot POS\'ga yuborilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _dispatching.add(order.id));
    try {
      final delivery = await _service.dispatchOrder(order.id);
      if (!mounted) return;
      setState(() {
        order.delivery = delivery;
        _dispatching.remove(order.id);
      });
      _showSnack('#${order.orderId} POS\'ga yuborildi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dispatching.remove(order.id));
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
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
          'POS buyurtmalari',
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
    if (_loading && _orders == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && _orders == null) {
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

    final orders = _orders ?? const <PosOrder>[];
    if (orders.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hozircha POS buyurtmalari yo\'q',
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
      itemCount: orders.length,
      itemBuilder: (context, index) => _orderCard(orders[index]),
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

  // Bitta buyurtma kartasi: kod + sana + filial + summa + status chip,
  // itemlar ro'yxati va (yuborilmagan bo'lsa) «Bazadan yuborish» tugmasi.
  Widget _orderCard(PosOrder order) {
    final delivery = order.delivery;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1-qator: buyurtma kodi + status chipi.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.orderId}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _statusChip(delivery),
              ],
            ),
            const SizedBox(height: 4),
            // 2-qator: sana + filial.
            Text(
              '${_fmtDate(order.created)} · ${order.filialName}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            // Itemlar: yuborilgandan keyin delivery itemlari (qabul holati
            // bilan), yuborilmagan bo'lsa — buyurtma itemlari.
            if (delivery == null)
              for (final item in order.items) _orderItemRow(item)
            else
              for (final item in delivery.items) _deliveryItemRow(item),
            const SizedBox(height: 6),
            // Jami summa (butun so'm, probel bilan ajratilgan).
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Jami: ${fmtCostMoney(order.total)} so\'m',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (delivery == null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _dispatching.contains(order.id)
                      ? null
                      : () => _dispatch(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: _dispatching.contains(order.id)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Bazadan yuborish'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Status chipi: yuborilmagan — kulrang, yuborilgan — ko'k, qabul — yashil.
  Widget _statusChip(PosDelivery? delivery) {
    final String label;
    final Color color;
    if (delivery == null) {
      label = 'Yuborilmagan';
      color = Colors.grey.shade600;
    } else if (delivery.status == 'completed') {
      label = 'Qabul qilingan';
      color = _kAccepted;
    } else {
      label = 'Yuborilgan';
      color = _kSent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
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

  // Yuborilmagan buyurtma qatori: nom — miqdor birlik.
  Widget _orderItemRow(PosOrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
            formatQtyUnit(item.count, item.unit),
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

  // Yuborilgan qator: nom — yuborilgan miqdor + qabul holati
  // («kutilmoqda» / «qabul: N» — kamomad qizil).
  Widget _deliveryItemRow(PosDeliveryItem item) {
    final Widget acceptedLabel;
    if (item.acceptedQty == null) {
      acceptedLabel = Text(
        'kutilmoqda',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade500,
        ),
      );
    } else {
      acceptedLabel = Text(
        'qabul: ${formatQtyUnit(item.acceptedQty!, item.unit)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: item.isShortfall ? _kShortfall : _kAccepted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatQtyUnit(item.sentQty, item.unit),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              acceptedLabel,
            ],
          ),
        ],
      ),
    );
  }
}
