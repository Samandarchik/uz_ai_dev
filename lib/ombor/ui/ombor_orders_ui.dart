import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/media/network_video_player.dart';
import 'package:uz_ai_dev/core/media/telegram_style_video_recorder.dart';
import 'package:uz_ai_dev/core/media/video_processor.dart';
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

class _OrderCard extends StatefulWidget {
  final OmborOrder order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  OmborOrder get order => widget.order;

  // Har bir mahsulot (product_id) uchun olingan rasm/video lokal fayl yo'li.
  final Map<int, String> _images = {};
  final Map<int, String> _videos = {};
  // Har bir mahsulot uchun "Kelgan soni" (haqiqatda kelgan miqdor) controlleri.
  final Map<int, TextEditingController> _received = {};
  // Double-tap bilan qayta tahrirlashga ochilgan (allaqachon qabul qilingan)
  // itemlar. Buyurtma to'liq yopilmaguncha omborchi xato kiritgan sonni
  // shu yo'l bilan tuzatishi mumkin.
  final Set<int> _reEditing = {};

  final ImagePicker _picker = ImagePicker();

  // Qabul qilingan itemni double-tap bilan qayta tahrirlashga ochish.
  void _startReEdit(OmborOrderItem item) {
    _received.putIfAbsent(item.productId, () => TextEditingController());
    _received[item.productId]!.text = _fmtQty(item.received);
    setState(() => _reEditing.add(item.productId));
  }

  @override
  void initState() {
    super.initState();
    // "Kelgan soni" maydonini oldindan to'ldiramiz; omborchi kam bo'lsa
    // o'zgartiradi. Narxlangan buyurtmada — yuk keltiruvchi aytgan miqdor
    // (taken), hali narxlanmagan (created) buyurtmada — buyurtma soni (count).
    // Rasxod (xarajat) itemlari va allaqachon qabul qilingan itemlar uchun
    // controller ochilmaydi (ular read-only ko'rinadi).
    if (order.isPriced || order.isCreated) {
      for (final item in order.items) {
        if (item.isRasxod || item.accepted) continue;
        _received[item.productId] = TextEditingController(
          text: _fmtQty(order.isPriced ? item.taken : item.count),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _received.values) {
      c.dispose();
    }
    super.dispose();
  }

  // "Kelgan soni" matnini songa aylantirish (vergul -> nuqta).
  double _parseQty(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }

  // Omborchi kiritgan "Kelgan soni" lar bo'yicha jonli umumiy summa.
  // Backend bilan bir xil: birlik narx = subtotal/taken, received bo'yicha
  // qayta hisoblanadi (kam qabul qilinsa summa kamayadi).
  double _liveTotal() {
    double total = 0;
    for (final item in order.items) {
      // Rasxod (xarajat) mahsulot summasiga kirmaydi.
      if (item.isRasxod) continue;
      // Qabul qilingan itemda backend saqlagan received, tahrirlanayotganda
      // controllerdagi qiymat, aks holda taken ishlatiladi.
      final received = item.accepted
          ? (item.received > 0 ? item.received : item.taken)
          : (_received.containsKey(item.productId)
              ? _parseQty(_received[item.productId]!.text)
              : item.taken);
      if (item.taken > 0 && received != item.taken) {
        total += (item.subtotal / item.taken) * received;
      } else {
        total += item.subtotal;
      }
    }
    return total;
  }

  // Kamera katakchasi bosilganda: "Rasm olish" yoki "Video olish" tanlovi.
  // Tanlovga qarab _captureImage yoki _captureVideo ishlaydi.
  Future<void> _pickMedia(int productId) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Rasm yoki video', style: TextStyle(fontSize: 16)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('image'),
            child: const Row(
              children: [
                Icon(Icons.photo_camera_outlined, color: Colors.black87),
                SizedBox(width: 12),
                Text('Rasm olish'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('video'),
            child: const Row(
              children: [
                Icon(Icons.videocam_outlined, color: Colors.black87),
                SizedBox(width: 12),
                Text('Video olish'),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'image') {
      await _captureImage(productId);
    } else {
      await _captureVideo(productId);
    }
  }

  // Mahsulot uchun rasm olish (kamera).
  Future<void> _captureImage(int productId) async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (x != null) {
      if (!mounted) return;
      setState(() => _images[productId] = x.path);
    }
  }

  // Mahsulot uchun aylana video yozish.
  Future<void> _captureVideo(int productId) async {
    final segments = await Navigator.of(context).push<List<XFile>>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => const TelegramStyleVideoRecorder(),
      ),
    );
    if (segments == null || segments.isEmpty) return;
    if (!mounted) return;

    // Yozilgan videoni kvadrat (1:1) qirqib, 480p ga siqamiz —
    // Telegram video note uslubi: kichik hajm, sifat saqlanadi.
    final messenger = ScaffoldMessenger.of(context);
    _showProcessingDialog();
    try {
      final processedPath = await VideoProcessor.toSquareNote(
        segments.map((e) => e.path).toList(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dialogni yopish
      setState(() => _videos[productId] = processedPath);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dialogni yopish
      // Qayta ishlash muvaffaqiyatsiz bo'lsa ham video yuborilsin:
      // xom (qayta ishlanmagan) birinchi segment ishlatiladi. Ilovada baribir
      // aylana (ClipOval) ko'rinishda chiqadi, faqat hajmi kattaroq bo'ladi.
      setState(() => _videos[productId] = segments.first.path);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Video siqilmadi, asl holicha yuboriladi (hajmi kattaroq)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Video qayta ishlanayotganda chiqadigan progress oynasi.
  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Video tayyorlanmoqda...')),
          ],
        ),
      ),
    );
  }

  // Bitta mahsulotni qabul qilish: kelgan soni + rasm/video yuboriladi.
  // Rasm ham video ham bo'lmasa yuborilmaydi (kamida bittasi majburiy).
  Future<void> _acceptItem(OmborOrderItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OmborProvider>();
    final productId = item.productId;

    final imagePath = _images[productId];
    final videoPath = _videos[productId];
    // Yangi media majburiy — faqat itemda avvaldan saqlangan rasm/video
    // bo'lmasa (qayta tahrirlashda eski rasm yetarli).
    final hasExistingMedia =
        item.imageUrl.isNotEmpty || item.videoUrl.isNotEmpty;
    if (imagePath == null && videoPath == null && !hasExistingMedia) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Avval rasm yoki video oling')),
      );
      return;
    }

    final received = _received.containsKey(productId)
        ? _parseQty(_received[productId]!.text)
        : 0.0;

    try {
      await provider.acceptOrderItem(
        order.id,
        productId,
        received,
        imagePath,
        videoPath,
      );
      if (!mounted) return;
      // Yuborilgan lokal fayllar endi kerak emas — backenddan kelgan
      // yangilangan order o'z URL'larini olib keladi. Qayta tahrirlash
      // rejimi ham yopiladi.
      setState(() {
        _images.remove(productId);
        _videos.remove(productId);
        _reEditing.remove(productId);
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
          // Itemlar. Narxlangan/yangi (created)/qabul qilingan bo'lsa —
          // jadval: Mahsulot | Kelgan soni | Rasm/Video | Qabul;
          // aks holda oddiy ro'yxat.
          if (order.isPriced || order.isCreated || order.isAccepted) ...[
            const _MediaTableHeader(),
            // Rasxod (xarajat) itemlari jadvalga kirmaydi — ular pastdagi
            // "Xarajatlar" blokida (qabul qilinmaydi, rasm/video yo'q).
            // Har mahsulot alohida qabul qilinadi; item.accepted bo'lsa
            // qatori read-only bo'lib qoladi.
            ...order.items.where((i) => !i.isRasxod).map(
              (item) => Consumer<OmborProvider>(
                builder: (ctx, p, _) => _MediaItemRow(
                  item: item,
                  // Qabul qilingan item read-only, LEKIN buyurtma hali to'liq
                  // yopilmagan bo'lsa double-tap bilan qayta ochish mumkin.
                  editable: (order.isPriced || order.isCreated) &&
                      (!item.accepted ||
                          _reEditing.contains(item.productId)),
                  receivedController: _received[item.productId],
                  localImagePath: _images[item.productId],
                  localVideoPath: _videos[item.productId],
                  isAccepting: p.acceptingItemOrderId == order.id &&
                      p.acceptingItemProductId == item.productId,
                  onReceivedChanged: () => setState(() {}),
                  onTapMedia: () => _pickMedia(item.productId),
                  onAccept: () => _acceptItem(item),
                  onDoubleTap: (order.isPriced || order.isCreated) &&
                          item.accepted &&
                          !_reEditing.contains(item.productId)
                      ? () => _startReEdit(item)
                      : null,
                ),
              ),
            ),
            // Xarajatlar bloki (rasxod itemlari: nomi + summa).
            if (order.items.any((i) => i.isRasxod)) ...[
              const Divider(height: 20),
              const Text(
                'Xarajatlar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              ...order.items.where((i) => i.isRasxod).map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '${_formatSum(item.subtotal)} so\'m',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ] else
            ...order.items.map((item) => _OrderItemRow(item: item)),
          // Chek yakuni (narxlangan yoki qabul qilingan bo'lsa):
          // Mahsulot / Xarajat (bo'lsa) / Jami. Yuk keltiruvchi hali
          // yubormasdan (draft) narx kiritayotganida ham summalar socket
          // orqali jonli ko'rinadi — bironta itemda summa paydo bo'lishi
          // bilan blok chiqadi.
          if (order.isPriced ||
              order.isAccepted ||
              order.items.any((i) => i.subtotal > 0)) ...[
            const Divider(height: 20),
            Builder(
              builder: (_) {
                // Tahrirlanadigan (narxlangan) buyurtmada mahsulot summasi
                // kiritilgan "Kelgan soni" lar bo'yicha jonli hisoblanadi.
                // Qabul qilingan buyurtmada esa backenddan kelgan
                // received_total ishlatiladi. Asl summadan farq qilsa:
                // eskisi qizil + chizilgan, yangisi yashilda.
                final double newTotal;
                final bool reduced;
                if (order.isPriced) {
                  newTotal = _liveTotal();
                  reduced = (newTotal - order.total).abs() > 0.0001;
                } else if (order.isAccepted &&
                    order.receivedTotal > 0 &&
                    (order.receivedTotal - order.total).abs() > 0.0001) {
                  newTotal = order.receivedTotal;
                  reduced = true;
                } else {
                  newTotal = order.total;
                  reduced = false;
                }
                final expenses = order.expensesTotal;
                final grandTotal = newTotal + expenses;

                Widget mahsulotValue;
                if (!reduced) {
                  mahsulotValue = Text(
                    '${_formatSum(newTotal)} so\'m',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  );
                } else {
                  mahsulotValue = Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatSum(order.total)} so\'m',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red,
                          decorationThickness: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatSum(newTotal)} so\'m',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mahsulot:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        mahsulotValue,
                      ],
                    ),
                    if (expenses > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Xarajat:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${_formatSum(expenses)} so\'m',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
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
                          '${_formatSum(grandTotal)} so\'m',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          // Eslatma: buyurtma darajasidagi katta "Qabul qiling" tugmasi yo'q —
          // omborchi har mahsulotni qatoridagi tugma bilan alohida qabul
          // qiladi; hamma item qabul bo'lsa backend statusni o'zi
          // 'qabul_qilindi' qiladi.
          // Qabul qilingan buyurtma -> belgi.
          if (order.isAccepted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 18, color: Color(0xFF2E7D32)),
                  SizedBox(width: 6),
                  Text(
                    'Qabul qilindi',
                    style: TextStyle(
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

// Jadval sarlavhasi: Mahsulot | Kelgan soni | Rasm/Video | Qabul.
class _MediaTableHeader extends StatelessWidget {
  const _MediaTableHeader();

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
            child: Text('Kelgan soni',
                textAlign: TextAlign.center, style: style),
          ),
          SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text('Rasm/Video',
                textAlign: TextAlign.center, style: style),
          ),
          SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text('Qabul', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

// Mahsulot qatori: nom + farq + birlik narxi | "Kelgan soni" maydoni |
// Rasm/Video (bitta katak) | Qabul tugmasi.
class _MediaItemRow extends StatelessWidget {
  final OmborOrderItem item;
  // Buyurtma narxlangan yoki created VA item hali qabul qilinmagan ->
  // media/son kiritiladi va qabul tugmasi ko'rinadi. Aks holda (item yoki
  // butun order qabul qilingan) qator read-only.
  final bool editable;
  final TextEditingController? receivedController;
  final String? localImagePath;
  final String? localVideoPath;
  // Shu item hozir serverga yuborilmoqda (tugmada spinner).
  final bool isAccepting;
  final VoidCallback onReceivedChanged;
  // Rasm/Video katakchasi bosilganda tanlov dialogini ochadi.
  final VoidCallback onTapMedia;
  // Qabul tugmasi bosilganda itemni serverga yuboradi.
  final VoidCallback onAccept;
  // Qabul qilingan qator double-tap qilinsa qayta tahrirlashga ochiladi
  // (buyurtma to'liq yopilmagan bo'lsa). null -> double-tap ishlamaydi.
  final VoidCallback? onDoubleTap;

  const _MediaItemRow({
    required this.item,
    required this.editable,
    required this.receivedController,
    required this.localImagePath,
    required this.localVideoPath,
    required this.isAccepting,
    required this.onReceivedChanged,
    required this.onTapMedia,
    required this.onAccept,
    this.onDoubleTap,
  });

  static const Color _accent = Color(0xFFC5A97B);
  static const Color _red = Color(0xFFC62828);
  static const Color _green = Color(0xFF2E7D32);

  double _parse(String raw) {
    final c = raw.trim().replaceAll(',', '.');
    if (c.isEmpty) return 0;
    return double.tryParse(c) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final taken = item.taken;
    final subtotal = item.subtotal;
    final unitPrice = (taken > 0 && subtotal > 0) ? subtotal / taken : null;
    final unitLabel =
        unitPrice != null ? '${_fmtQty(taken)} * ${_formatSum(unitPrice)}' : '';
    final diff = taken - item.count;
    // Proche (yuk keltiruvchi qo'shgan) mahsulotda buyurtma soni yo'q —
    // farq ko'rsatilmaydi.
    final showDiff = !item.isProche && taken > 0 && diff.abs() > 0.0001;
    final diffText =
        diff > 0 ? '+${_fmtQty(diff)}' : '-${_fmtQty(diff.abs())}';
    final diffColor = diff > 0 ? _green : _red;
    final qtyLabel = item.isProche
        ? 'Qo\'shimcha'
        : '${_formatCount(item.count)}${item.type.isNotEmpty ? ' ${item.type}' : ''}';

    // Kelgan soni (haqiqatda kelgan) va taken (yuk keltiruvchi aytgan) farqi.
    final received =
        editable ? _parse(receivedController?.text ?? '') : item.received;
    final shortage = taken - received; // >0 = kam kelgan (kamomad)
    final showShort = taken > 0 && received > 0 && shortage.abs() > 0.0001;
    final shortText =
        shortage > 0 ? '-${_fmtQty(shortage)}' : '+${_fmtQty(shortage.abs())}';
    final shortColor = shortage > 0 ? _red : _green;

    return GestureDetector(
      // Qabul qilingan qatorni double-tap bilan qayta tahrirlashga ochish.
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nom + ma'lumot.
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
          // Kelgan soni + kamomad belgisi.
          Expanded(
            flex: 3,
            child: Column(
              children: [
                editable ? _receivedField() : _receivedView(),
                if (showShort) ...[
                  const SizedBox(height: 2),
                  Text(
                    shortText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: shortColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Rasm/Video — bitta katak (bosilganda rasm/video tanlov dialogi).
          Expanded(flex: 2, child: _mediaCell(context)),
          const SizedBox(width: 6),
          // Qabul tugmasi (yoki qabul qilingan bo'lsa yashil check).
          Expanded(flex: 2, child: _acceptCell()),
        ],
      ),
      ),
    );
  }

  Widget _receivedField() {
    return TextField(
      controller: receivedController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      onChanged: (_) => onReceivedChanged(),
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    );
  }

  Widget _receivedView() {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        _fmtQty(item.received),
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }

  // Rasm/Video kataги. Tahrirlanadigan qatorda: lokal rasm bo'lsa
  // thumbnail, faqat video bo'lsa yashil videocam, hech nima bo'lmasa
  // kamera ikonkasi — bosilganda har doim tanlov dialogi ochiladi.
  // Qabul qilingan qatorda: saqlangan rasm (bosilsa katta ko'rish) yoki
  // video (bosilsa aylana pleer).
  Widget _mediaCell(BuildContext context) {
    if (editable) {
      if (localImagePath != null) {
        return _MediaThumb(
          onTap: onTapMedia,
          child: Image.file(File(localImagePath!), fit: BoxFit.cover),
        );
      }
      if (localVideoPath != null) {
        return _MediaButton(
          icon: Icons.videocam,
          filled: true,
          onTap: onTapMedia,
        );
      }
      return _MediaButton(
        icon: Icons.photo_camera_outlined,
        onTap: onTapMedia,
      );
    }
    if (item.imageUrl.isNotEmpty) {
      final url = '${AppUrls.baseUrl}${item.imageUrl}';
      return _MediaThumb(
        onTap: () => _showFullImage(context, url),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 18, color: Colors.grey),
        ),
      );
    }
    if (item.videoUrl.isNotEmpty) {
      // Bosilganda videoni aylana shaklida (Telegram video note kabi) ko'rsatadi.
      return _MediaButton(
        icon: Icons.play_circle_fill,
        filled: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CircularNetworkVideoPlayer(
              url: '${AppUrls.baseUrl}${item.videoUrl}',
            ),
          ),
        ),
      );
    }
    return const _MediaEmpty();
  }

  // Saqlangan rasmni to'liq ekranda (kattalashtirib) ko'rish.
  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Qabul kataги: tahrirlanadigan qatorda yashil check tugma (yuborishda
  // spinner), qabul qilingan qatorda yashil check belgisi.
  Widget _acceptCell() {
    if (!editable) {
      // Item (yoki butun order) qabul qilingan — belgigina ko'rsatiladi.
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _green.withValues(alpha: 0.4)),
        ),
        child: const Icon(Icons.check_circle, size: 22, color: _green),
      );
    }
    return Material(
      color: isAccepting ? Colors.grey.shade300 : _green,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isAccepting ? null : onAccept,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: isAccepting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

// Rasm/Video olish tugmasi — faqat ikonka (quti ko'rinishida).
class _MediaButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  const _MediaButton({
    required this.icon,
    this.filled = false,
    this.onTap,
  });

  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final color = filled ? _green : Colors.grey.shade600;
    return Material(
      color: filled
          ? _green.withValues(alpha: 0.10)
          : const Color(0xFFF5F1EA),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: filled ? _green.withValues(alpha: 0.4) : Colors.grey.shade300,
            ),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// Olingan rasm thumbnaili.
class _MediaThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _MediaThumb({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

// Media yo'q (qabul qilingan, lekin bu mahsulotga yuborilmagan).
class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text('—', style: TextStyle(color: Colors.grey.shade500)),
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
