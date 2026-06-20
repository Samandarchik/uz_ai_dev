import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/media/telegram_style_video_recorder.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';

// Ombor o'zi bergan buyurtmalar ekrani.
// Yuk keltiruvchi narxlab qaytarganda status "narxlandi" bo'ladi.
class OmborOrdersUi extends StatefulWidget {
  const OmborOrdersUi({super.key});

  @override
  State<OmborOrdersUi> createState() => _OmborOrdersUiState();
}

class _OmborOrdersUiState extends State<OmborOrdersUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Mening buyurtmalarim',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: const OmborOrdersView(),
    );
  }
}

// Ombor buyurtmalari ro'yxati (mazmuni) — ham eski ekran, ham bosh ekrandagi
// "Buyurtmalarim" tabи shuni ishlatadi. Tab/ekran ochilganda buyurtmalar
// yuklanadi; loading/error/bo'sh/pull-to-refresh holatlari shu yerda.
class OmborOrdersView extends StatefulWidget {
  const OmborOrdersView({super.key});

  @override
  State<OmborOrdersView> createState() => _OmborOrdersViewState();
}

class _OmborOrdersViewState extends State<OmborOrdersView> {
  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OmborProvider>().fetchMyOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OmborProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingOrders) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (provider.ordersError != null) {
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
                    provider.ordersError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchMyOrders(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            ),
          );
        }

        final orders = provider.myOrders;
        if (orders.isEmpty) {
          return RefreshIndicator(
            color: _accentColor,
            onRefresh: () => provider.fetchMyOrders(),
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Hozircha buyurtmalar yo\'q',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: _accentColor,
          onRefresh: () => provider.fetchMyOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: orders.length,
            itemBuilder: (context, index) =>
                _OrderCard(order: orders[index]),
          ),
        );
      },
    );
  }
}

// Summani probel bilan formatlash: 1000 -> "1 000".
String _formatSum(double v) {
  final intPart = v.round();
  final str = intPart.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
    buf.write(str[i]);
  }
  final sign = intPart < 0 ? '-' : '';
  return '$sign${buf.toString()}';
}

// Miqdorni formatlash: 3.0 -> "3", 1.5 -> "1.5".
String _formatCount(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

// Miqdor: 3 xonagacha yaxlitlab, ortiqcha nollarni olib tashlaydi
// (8.5 -> "8.5", 8 -> "8", 0.2999999 -> "0.3").
String _fmtQty(double v) {
  if (v == 0) return '0';
  var s = v.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

// "2026-06-20T12:34:..." -> "2026-06-20 12:34".
String _formatDate(String raw) {
  if (raw.isEmpty) return '';
  final t = raw.indexOf('T');
  if (t == -1) return raw;
  final datePart = raw.substring(0, t);
  final rest = raw.substring(t + 1);
  final timePart =
      rest.length >= 5 ? rest.substring(0, 5) : rest;
  return '$datePart $timePart';
}

class _OrderCard extends StatelessWidget {
  final OmborOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarlavha qatori: order_id + status badge.
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.orderId}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 6),
          if (order.skladName.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.store_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.skladName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          if (order.created.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(order.created),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          // Itemlar. Narxlangan/qabul qilingan bo'lsa — yuk keltiruvchidagidek
          // jadval (Nechta olgani / Jami summa), aks holda oddiy ro'yxat.
          if (order.isPriced || order.isAccepted) ...[
            const _PriceTableHeader(),
            ...order.items.map((item) => _PricedItemRow(item: item)),
          ] else
            ...order.items.map((item) => _OrderItemRow(item: item)),
          // Jami (narxlangan yoki qabul qilingan bo'lsa).
          if (order.isPriced || order.isAccepted) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jami:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${_formatSum(order.total)} so\'m',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ],
          // Narxlangan buyurtma -> "Qabul qiling" (video yozib yuboriladi).
          if (order.isPriced) ...[
            const SizedBox(height: 12),
            Consumer<OmborProvider>(
              builder: (ctx, p, _) {
                final loading = p.acceptingOrderId == order.id;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : () => _acceptWithVideo(context),
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.videocam, size: 20),
                    label: Text(loading ? 'Yuborilmoqda...' : 'Qabul qiling'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          // Qabul qilingan buyurtma -> belgi va video soni.
          if (order.isAccepted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Text(
                    order.videoUrls.isNotEmpty
                        ? 'Qabul qilindi • ${order.videoUrls.length} video'
                        : 'Qabul qilindi',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // "Qabul qiling" bosilganda: aylana video rekorderni ochadi, yozilgan
  // video(lar)ni backendga yuboradi va buyurtmani qabul qiladi.
  Future<void> _acceptWithVideo(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OmborProvider>();

    final segments = await Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        builder: (_) => const TelegramStyleVideoRecorder(),
      ),
    );
    // Foydalanuvchi bekor qilgan bo'lsa (orqaga) — hech narsa qilinmaydi.
    if (segments == null || segments.isEmpty) return;

    try {
      await provider.acceptOrder(
        order.id,
        segments.map((e) => e.path).toList(),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Qabul qilindi')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _OrderItemRow extends StatelessWidget {
  final OmborOrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final qtyLabel =
        '${_formatCount(item.count)}${item.type.isNotEmpty ? ' ${item.type}' : ''}';
    final priced = item.taken > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  priced
                      ? '$qtyLabel  •  ${_formatSum(item.taken)} olindi'
                      : qtyLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (priced)
            Text(
              '${_formatSum(item.subtotal)} so\'m',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
        ],
      ),
    );
  }
}

// Yuk keltiruvchidagidek jadval sarlavhasi.
class _PriceTableHeader extends StatelessWidget {
  const _PriceTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
    );
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Mahsulot', style: style)),
          SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text('Nechta olgani',
                textAlign: TextAlign.center, style: style),
          ),
          SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Text('Jami summa',
                textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

// Narxlangan mahsulot qatori: nom + olingan/buyurtma farqi + birlik narxi,
// o'ngda "Nechta olgani" va "Jami summa" (read-only) qutilar.
class _PricedItemRow extends StatelessWidget {
  final OmborOrderItem item;
  const _PricedItemRow({required this.item});

  static const Color _accent = Color(0xFFC5A97B);

  @override
  Widget build(BuildContext context) {
    final taken = item.taken;
    final subtotal = item.subtotal;
    final unitPrice = (taken > 0 && subtotal > 0) ? subtotal / taken : null;
    final unitLabel =
        unitPrice != null ? '${_fmtQty(taken)} * ${_formatSum(unitPrice)}' : '';
    final diff = taken - item.count;
    final showDiff = taken > 0 && diff.abs() > 0.0001;
    final diffText =
        diff > 0 ? '+${_fmtQty(diff)}' : '-${_fmtQty(diff.abs())}';
    final diffColor =
        diff > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final qtyLabel =
        '${_formatCount(item.count)}${item.type.isNotEmpty ? ' ${item.type}' : ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      qtyLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (showDiff) ...[
                      const SizedBox(width: 6),
                      Text(
                        diffText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: diffColor,
                        ),
                      ),
                    ],
                  ],
                ),
                if (unitPrice != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    unitLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _ReadOnlyBox(text: taken > 0 ? _fmtQty(taken) : '0'),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: _ReadOnlyBox(text: subtotal > 0 ? _formatSum(subtotal) : '0'),
          ),
        ],
      ),
    );
  }
}

// Read-only (faqat ko'rish uchun) qiymat qutisi — yuk keltiruvchidagi
// o'chirilgan maydon ko'rinishida.
class _ReadOnlyBox extends StatelessWidget {
  final String text;
  const _ReadOnlyBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // narxlandi holatida badge ko'rsatilmaydi — uning o'rniga pastda
    // "Qabul qiling" tugmasi chiqadi.
    if (status == 'narxlandi') return const SizedBox.shrink();

    final bool accepted = status == 'qabul_qilindi';
    final Color bg = accepted
        ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
        : const Color(0xFF1565C0).withValues(alpha: 0.12);
    final Color fg =
        accepted ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    final String label = accepted ? 'Qabul qilindi' : 'Yuborildi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
