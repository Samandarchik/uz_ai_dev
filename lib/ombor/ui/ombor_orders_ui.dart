// ombor/ui/ombor_orders_ui.dart — Ombor buyurtmalari ekranlari: OmborOrdersUi, OmborOrdersHistoryUi va
// umumiy OmborOrdersView (OmborProvider). Qatorda kelgan soni + rasm/video bilan qabul qilish/o'chirish.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/media/in_app_photo_camera.dart';
import 'package:uz_ai_dev/core/media/network_video_player.dart';
import 'package:uz_ai_dev/core/media/telegram_style_video_recorder.dart';
import 'package:uz_ai_dev/core/media/video_processor.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
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

// Qabul qilingan buyurtmalar tarixi — bosh ekrandagi AppBar'dagi tarix
// tugmasidan ochiladi (yuk keltiruvchidagi kabi). Faqat status
// "qabul_qilindi" bo'lgan buyurtmalar ko'rinadi.
class OmborOrdersHistoryUi extends StatelessWidget {
  const OmborOrdersHistoryUi({super.key});

  static const Color _bgColor = Color(0xFFFAF6F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Qabul qilinganlar tarixi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: const OmborOrdersView(acceptedOnly: true),
    );
  }
}

// Ombor buyurtmalari ro'yxati (mazmuni) — ham eski ekran, ham bosh ekrandagi
// "Buyurtmalarim" tabи shuni ishlatadi. Tab/ekran ochilganda buyurtmalar
// yuklanadi; loading/error/bo'sh/pull-to-refresh holatlari shu yerda.
// acceptedOnly=false (default): faqat hali qabul qilinmagan (yuborilgan)
// buyurtmalar; acceptedOnly=true: faqat qabul qilinganlar (tarix ekrani).
// Buyurtmalar sklad bo'yicha guruhlanib, har sklad uchun BITTA jamlangan
// karta chiqadi (order_id ko'rsatilmaydi).
class OmborOrdersView extends StatefulWidget {
  final bool acceptedOnly;
  const OmborOrdersView({super.key, this.acceptedOnly = false});

  @override
  State<OmborOrdersView> createState() => _OmborOrdersViewState();
}

class _OmborOrdersViewState extends State<OmborOrdersView> {
  static const Color _accentColor = Color(0xFFC5A97B);

  // Tarix (acceptedOnly) ekrani: shu kunda qabul qilingan (kelgan)
  // buyurtmalar ko'rsatiladi. Standart — bugun.
  DateTime _selectedDate = _todayDate();

  static DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OmborProvider>().fetchMyOrders();
    });
  }

  // "2026-07-12" — order.created bilan solishtirish uchun kalit.
  String _dateKeyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // "12.07.2026" — sana navigatsiyasidagi yozuv.
  String _dateLabelOf(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  // Buyurtma kuni — created ning YYYY-MM-DD qismi.
  String _orderDateKey(OmborOrder o) =>
      o.created.length >= 10 ? o.created.substring(0, 10) : o.created;

  bool get _isToday => _dateKeyOf(_selectedDate) == _dateKeyOf(_todayDate());

  void _setDate(DateTime d) =>
      setState(() => _selectedDate = DateTime(d.year, d.month, d.day));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: _todayDate(),
    );
    if (picked != null) _setDate(picked);
  }

  // Bozor ekranidagi kabi sana navigatsiyasi: ‹ 12.07.2026 › — o'rtaga
  // bosilsa kalendardan sana tanlanadi, strelkalar kunni oldinga/orqaga.
  Widget _dateNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              _setDate(_selectedDate.subtract(const Duration(days: 1))),
        ),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today,
                    size: 15, color: _accentColor),
                const SizedBox(width: 8),
                Text(
                  _dateLabelOf(_selectedDate),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          // Kelajak kunga o'tib bo'lmaydi.
          onPressed: _isToday
              ? null
              : () => _setDate(_selectedDate.add(const Duration(days: 1))),
        ),
      ],
    );
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

        // Asosiy tabда qabul qilinganlar ko'rinmaydi (ular tarixda),
        // tarix ekranida esa faqat qabul qilinganlar chiqadi.
        var orders = provider.myOrders
            .where((o) => o.isAccepted == widget.acceptedOnly)
            .toList();

        // Asosiy "Buyurtmalarim" tabi — sana filtrsiz (hamma yuborilgan
        // buyurtma). Tarix (qabul qilinganlar) — tanlangan kun bo'yicha
        // filtr + yuqorida sana navigatsiyasi (bozor ekranidagi kabi).
        if (!widget.acceptedOnly) {
          return _ordersList(context, provider, orders);
        }
        final dayKey = _dateKeyOf(_selectedDate);
        orders = orders.where((o) => _orderDateKey(o) == dayKey).toList();
        return Column(
          children: [
            const SizedBox(height: 4),
            _dateNav(),
            const Divider(height: 1),
            Expanded(child: _ordersList(context, provider, orders)),
          ],
        );
      },
    );
  }

  // Sklad bo'yicha guruhlangan kartalar ro'yxati yoki bo'sh holat —
  // ikkalasi ham pull-to-refresh bilan.
  Widget _ordersList(
    BuildContext context,
    OmborProvider provider,
    List<OmborOrder> orders,
  ) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        color: _accentColor,
        onRefresh: () => provider.fetchMyOrders(),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long,
                        size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      widget.acceptedOnly
                          ? 'Bu kunda qabul qilingan buyurtmalar yo\'q'
                          : 'Hozircha buyurtmalar yo\'q',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Sklad nomi bo'yicha guruhlash — birinchi ko'ringan tartibni saqlaymiz
    // (myOrders id bo'yicha kamayuvchi). Har sklad uchun bitta karta.
    final groups = <String, List<OmborOrder>>{};
    for (final o in orders) {
      groups.putIfAbsent(o.skladName, () => <OmborOrder>[]).add(o);
    }
    final entries = groups.entries.toList();

    return RefreshIndicator(
      color: _accentColor,
      onRefresh: () => provider.fetchMyOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        itemBuilder: (context, index) => _SkladDayCard(
          key: ValueKey(entries[index].key),
          skladName: entries[index].key,
          orders: entries[index].value,
        ),
      ),
    );
  }
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

// Bitta sklad uchun jamlangan karta: o'sha skladga tegishli barcha
// buyurtmalarning (rasxod bo'lmagan) mahsulotlari BITTA kartada. Sarlavhada
// faqat sklad nomi (order_id ko'rsatilmaydi), so'ng bitta jadval sarlavhasi
// va hamma buyurtmalarning mahsulot qatorlari. >1 buyurtma bo'lsa ularning
// orasida buyurtma vaqti bilan ingichka ajratuvchi chiqadi.
class _SkladDayCard extends StatefulWidget {
  final String skladName;
  final List<OmborOrder> orders;
  const _SkladDayCard({super.key, required this.skladName, required this.orders});

  @override
  State<_SkladDayCard> createState() => _SkladDayCardState();
}

class _SkladDayCardState extends State<_SkladDayCard> {
  static const Color _accent = Color(0xFFC5A97B);

  // Kalitlar KOMPOZIT: '${order.id}_${item.productId}'. Bitta kartada bir
  // nechta buyurtma bo'lgani uchun bir xil product_id turli buyurtmalarда
  // uchrashi mumkin — int product_id bilan kalitlash to'qnashardi. Har item
  // shu tariqa o'z buyurtmasiga bog'liq qoladi.
  final Map<String, String> _images = {};
  final Map<String, String> _videos = {};
  // Har (buyurtma, mahsulot) uchun "Kelgan soni" controlleri.
  final Map<String, TextEditingController> _received = {};

  String _keyOf(int orderId, int productId) => '${orderId}_$productId';

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _SkladDayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Real-time (socket) yangi buyurtma kelishi yoki item qabul qilinishi
    // bilan kerakli controllerlarni qo'shamiz, keraksizlarini tozalaymiz.
    _syncControllers();
  }

  // Har bir tahrirlanadigan item (qabul qilinmagan, rasxod bo'lmagan,
  // olib kelingan) uchun "Kelgan soni" controlleri borligini ta'minlaydi.
  // "Kelgan soni" maydoni: narxlangan buyurtmada yuk keltiruvchi aytgan
  // miqdor (taken) bilan to'ldiriladi; hali narxlanmagan (created)
  // buyurtmada BO'SH turadi — omborchi haqiqatda kelganini o'zi yozadi.
  void _syncControllers() {
    final valid = <String>{};
    for (final order in widget.orders) {
      if (!(order.isPriced || order.isCreated)) continue;
      for (final item in order.items) {
        // Rasxod (xarajat) va allaqachon qabul qilingan itemlar read-only.
        if (item.isRasxod || item.accepted) continue;
        // O'chirilgan item read-only (chizilgan) — controller ochilmaydi.
        if (item.deleted) continue;
        // Narxlangan buyurtmada umuman olib kelmagan mahsulot (taken 0,
        // summa 0) qabul qilinmaydi — controller ochilmaydi.
        if (order.isPriced && item.taken <= 0 && item.subtotal <= 0) continue;
        final k = _keyOf(order.id, item.productId);
        valid.add(k);
        _received.putIfAbsent(
          k,
          // taken API birlikda (кг/л -> gramm) — maydonga UI (kg) yoziladi.
          () => TextEditingController(
            text: order.isPriced ? formatQty(item.taken, item.type) : '',
          ),
        );
      }
    }
    // Endi kerak bo'lmagan (item qabul qilingan / buyurtma o'chgan)
    // controllerlarni tozalash.
    final stale = _received.keys.where((k) => !valid.contains(k)).toList();
    for (final k in stale) {
      _received.remove(k)?.dispose();
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

  // Kamera katakchasi bosilganda: "Rasm olish" yoki "Video olish" tanlovi.
  // Tanlovga qarab _captureImage yoki _captureVideo ishlaydi.
  Future<void> _pickMedia(String key) async {
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
      await _captureImage(key);
    } else {
      await _captureVideo(key);
    }
  }

  // Mahsulot uchun rasm olish — ilova ICHIDAGI kamera (InAppPhotoCamera).
  // image_picker'ning tashqi kamerasi Android'da ilovani orqa fonda
  // o'ldirilishiga (kiritilgan "Kelgan soni" qiymatlari yo'qolishiga)
  // sabab bo'lardi.
  Future<void> _captureImage(String key) async {
    final x = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => const InAppPhotoCamera()),
    );
    if (x != null) {
      if (!mounted) return;
      setState(() => _images[key] = x.path);
    }
  }

  // Mahsulot uchun aylana video yozish.
  Future<void> _captureVideo(String key) async {
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
      setState(() => _videos[key] = processedPath);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dialogni yopish
      // Qayta ishlash muvaffaqiyatsiz bo'lsa ham video yuborilsin:
      // xom (qayta ishlanmagan) birinchi segment ishlatiladi. Ilovada baribir
      // aylana (ClipOval) ko'rinishda chiqadi, faqat hajmi kattaroq bo'ladi.
      setState(() => _videos[key] = segments.first.path);
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
  // Item O'Z buyurtmasi (order) bilan yuboriladi — kompozit kalit orqali.
  Future<void> _acceptItem(OmborOrder order, OmborOrderItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OmborProvider>();
    final key = _keyOf(order.id, item.productId);

    final imagePath = _images[key];
    final videoPath = _videos[key];
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

    // Maydonda UI birlik (kg/l) — API'ga butun gramm/ml yuboriladi.
    // qtyFromUiSafe: 1000+ kiritilsa gramm deb olinadi (gramm-yozish himoyasi).
    final received = _received.containsKey(key)
        ? qtyFromUiSafe(_parseQty(_received[key]!.text), item.type).toDouble()
        : 0.0;

    // Kelgan soni kiritilmagan yoki 0 bo'lsa qabul yuborilmaydi —
    // rasm olingan bo'lsa ham. Omborchi haqiqiy sonni yozishi shart.
    if (received <= 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Kelgan soni kiritilmagan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"${item.name}" uchun kelgan soni 0 dan ko\'p bo\'lishi kerak. '
            'Avval haqiqatda kelgan miqdorni kiriting.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC5A97B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Tushunarli'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await provider.acceptOrderItem(
        order.id,
        item.productId,
        received,
        imagePath,
        videoPath,
      );
      if (!mounted) return;
      // Yuborilgan lokal fayllar endi kerak emas — backenddan kelgan
      // yangilangan order o'z URL'larini olib keladi.
      setState(() {
        _images.remove(key);
        _videos.remove(key);
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

  // Bitta mahsulotni buyurtmadan o'chirish: avval tasdiq dialogi, keyin
  // provider orqali serverga DELETE. Xato bo'lsa SnackBar ko'rsatiladi.
  Future<void> _deleteItem(OmborOrder order, OmborOrderItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OmborProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Mahsulotni o\'chirish',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text('"${item.name}" buyurtmadan o\'chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Bekor',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await provider.deleteOrderItem(order.id, item.productId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Buyurtma vaqti (soat:daqiqa) — _formatDate dan olinadi.
  String _orderTime(String created) {
    final f = _formatDate(created); // "2026-06-20 12:34"
    final parts = f.split(' ');
    return parts.length > 1 ? parts.last : f;
  }

  // Bir kartadagi ikki buyurtma orasidagi ingichka ajratuvchi — o'rtasida
  // buyurtma vaqti (masalan "04:20") ko'rsatiladi.
  Widget _orderSeparator(OmborOrder order) {
    final time = _orderTime(order.created);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: Colors.grey.shade300)),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 3),
            Text(
              time,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(height: 1, color: Colors.grey.shade300)),
          ],
        ],
      ),
    );
  }

  // Bitta mahsulot qatori — o'z buyurtmasi (order) bilan bog'langan.
  // notBrought/editable per-item mantiq o'sha itemning buyurtma statusiga
  // qarab hisoblanadi. isAccepting order-scoped (order.id + productId).
  Widget _itemRow(OmborOrder order, OmborOrderItem item) {
    final key = _keyOf(order.id, item.productId);
    // O'chirish mumkin: faqat katalog item (proche/rasxod emas), hali qabul
    // qilinmagan (mahsulot kelmagan) va order yopilmagan. PENDING buyurtmada
    // yuk summa yozib qo'ygan bo'lsa ham o'chiriladi (backend summani nolga
    // qaytaradi); yopiq (narxlandi) chekda esa faqat summasiz item — pul
    // ledgerga tushgan. Tarix (acceptedOnly) ekranida hamma order isAccepted
    // — u yerda ikonka chiqmaydi. Ombor UI'da pul ko'rsatilmaydi, subtotal
    // faqat shu shart uchun ishlatiladi.
    final deletable = !order.isAccepted &&
        !item.accepted &&
        !item.deleted &&
        item.itemType.isEmpty &&
        (order.isCreated || item.subtotal <= 0) &&
        item.received <= 0;
    return Consumer<OmborProvider>(
      builder: (ctx, p, _) => _MediaItemRow(
        item: item,
        // Yuk yuborgandan keyin umuman olib kelinmagan mahsulot
        // (taken 0, summa 0) — qabul qilinmaydi, "Olinmagan" ko'rinadi.
        notBrought: !order.isCreated &&
            !item.accepted &&
            item.taken <= 0 &&
            item.subtotal <= 0,
        // Qabul qilingan (yoki o'chirilgan) item read-only.
        editable: (order.isPriced || order.isCreated) &&
            !item.accepted &&
            !item.deleted &&
            !(order.isPriced &&
                item.taken <= 0 &&
                item.subtotal <= 0),
        deletable: deletable,
        receivedController: _received[key],
        localImagePath: _images[key],
        localVideoPath: _videos[key],
        isAccepting: p.acceptingItemOrderId == order.id &&
            p.acceptingItemProductId == item.productId,
        isDeleting: p.deletingItemOrderId == order.id &&
            p.deletingItemProductId == item.productId,
        onReceivedChanged: () => setState(() {}),
        onTapMedia: () => _pickMedia(key),
        onAccept: () => _acceptItem(order, item),
        onDelete: () => _deleteItem(order, item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    // Tarix (hammasi qabul qilingan) bo'lsa pastda bitta "Qabul qilindi"
    // belgisi chiqadi.
    final allAccepted = orders.isNotEmpty && orders.every((o) => o.isAccepted);

    // Guruhdagi har buyurtmaning rasxod bo'lmagan itemlari ketma-ket;
    // buyurtmalar orasida (>1 bo'lsa) vaqt bilan ajratuvchi.
    final rows = <Widget>[];
    var first = true;
    for (final order in orders) {
      final visible = order.items.where((it) => !it.isRasxod).toList();
      if (visible.isEmpty) continue;
      if (!first) rows.add(_orderSeparator(order));
      first = false;
      for (final item in visible) {
        rows.add(_itemRow(order, item));
      }
    }

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
          // Sarlavha: sklad nomi (do'kon ikonkasi + nom). Order ID YO'Q,
          // per-order status badge ham yo'q.
          Row(
            children: [
              const Icon(Icons.store_outlined, size: 18, color: _accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.skladName.isEmpty ? 'Buyurtma' : widget.skladName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // Jadval sarlavhasi bir marta: Mahsulot | Kelgan soni | Rasm/Video
          // | Qabul.
          const _MediaTableHeader(),
          ...rows,
          // Hammasi qabul qilingan (tarix) -> belgi.
          if (allAccepted) ...[
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
  // Yuk yuborgandan keyin umuman olib kelinmagan mahsulot — qatorda
  // "Olinmagan" belgisi ko'rinadi, qabul qilinmaydi.
  final bool notBrought;
  // Omborchi shu itemni buyurtmadan o'chira oladimi (qizil o'chirish ikonkasi).
  final bool deletable;
  final TextEditingController? receivedController;
  final String? localImagePath;
  final String? localVideoPath;
  // Shu item hozir serverga yuborilmoqda (tugmada spinner).
  final bool isAccepting;
  // Shu item hozir serverdan o'chirilmoqda (ikonka o'rnida spinner).
  final bool isDeleting;
  final VoidCallback onReceivedChanged;
  // Rasm/Video katakchasi bosilganda tanlov dialogini ochadi.
  final VoidCallback onTapMedia;
  // Qabul tugmasi bosilganda itemni serverga yuboradi.
  final VoidCallback onAccept;
  // O'chirish ikonkasi bosilganda tasdiq dialogini ochadi.
  final VoidCallback onDelete;

  const _MediaItemRow({
    required this.item,
    required this.editable,
    this.notBrought = false,
    this.deletable = false,
    required this.receivedController,
    required this.localImagePath,
    required this.localVideoPath,
    required this.isAccepting,
    this.isDeleting = false,
    required this.onReceivedChanged,
    required this.onTapMedia,
    required this.onAccept,
    required this.onDelete,
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
    final diff = taken - item.count;
    // Proche (yuk keltiruvchi qo'shgan) mahsulotda buyurtma soni yo'q —
    // farq ko'rsatilmaydi.
    final showDiff = !item.isProche && taken > 0 && diff.abs() > 0.0001;
    // Ortiqcha/kam farqi yonida birlik (type) ham ko'rsatiladi: "+8.2 kg".
    final diffUnit = item.type.isNotEmpty ? ' ${item.type}' : '';
    final diffText = diff > 0
        ? '+${formatQty(diff, item.type)}$diffUnit'
        : '-${formatQty(diff.abs(), item.type)}$diffUnit';
    final diffColor = diff > 0 ? _green : _red;
    final qtyLabel = item.isProche
        ? 'Qo\'shimcha'
        : '${formatQty(item.count, item.type)}${item.type.isNotEmpty ? ' ${item.type}' : ''}';

    // O'chirilgan item: nom + miqdor qizil chizilgan, o'ng tomonda
    // "O'chirildi" belgisi. Maydon/kamera/qabul tugmasi YO'Q.
    if (item.deleted) {
      const deletedStyle = TextStyle(
        color: Colors.red,
        decoration: TextDecoration.lineThrough,
        decorationColor: Colors.red,
      );
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
                    style: deletedStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(qtyLabel, style: deletedStyle.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 7,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _red.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'O\'chirildi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _red,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Kelgan soni (haqiqatda kelgan) va taken (yuk keltiruvchi aytgan) farqi.
    // Maydondagi matn UI birlikda — solishtirish uchun API birlikka o'giriladi.
    final received = editable
        ? qtyFromUiSafe(_parse(receivedController?.text ?? ''), item.type)
            .toDouble()
        : item.received;
    final shortage = taken - received; // >0 = kam kelgan (kamomad)
    final showShort = taken > 0 && received > 0 && shortage.abs() > 0.0001;
    final shortText = shortage > 0
        ? '-${formatQty(shortage, item.type)}'
        : '+${formatQty(shortage.abs(), item.type)}';
    final shortColor = shortage > 0 ? _red : _green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nom + ma'lumot (+ o'chirish mumkin bo'lsa qizil ikonka).
          Expanded(
            flex: 5,
            child: Row(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            qtyLabel,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
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
                      // Omborchi narx ko'rmaydi — birlik narx qatori ataylab yo'q.
                    ],
                  ),
                ),
                if (deletable)
                  GestureDetector(
                    onTap: isDeleting ? null : onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _red,
                              ),
                            )
                          : const Icon(Icons.delete_outline,
                              size: 19, color: _red),
                    ),
                  ),
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
        // Kiritilayotgan son yonida birlik (masalan "kg") ko'rinib turadi.
        suffixText: item.type.isNotEmpty ? item.type : null,
        suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
        notBrought
            ? '—'
            : '${formatQty(item.received, item.type)}'
                '${item.type.isNotEmpty ? ' ${item.type}' : ''}',
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
    if (notBrought) {
      // Olib kelinmagan mahsulot — qabul qilinmaydi.
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _red.withValues(alpha: 0.35)),
        ),
        child: const Text(
          'Olinmagan',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _red,
          ),
        ),
      );
    }
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
