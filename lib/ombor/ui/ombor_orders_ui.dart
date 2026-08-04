// ombor/ui/ombor_orders_ui.dart — Ombor buyurtmalari ekranlari: OmborOrdersUi (aktiv
// buyurtmalar), OmborOrdersHistoryUi (qabul qilinganlar, kun bo'yicha) va ikkalasi
// ishlatadigan OmborOrdersView.
//
// ⚡ TEZLIK UCHUN 0 DAN QAYTA YOZILGAN. Eski versiya iPhone 15 Pro Max'da ham qotib,
// ilovani o'ldirardi (OOM). Uchta sabab bor edi, uchalasi ham shu yerda yopildi:
//
//  1) RASM — 48px'lik katakcha uchun serverdagi 1024px rasm TO'LIQ dekod qilinardi:
//     bitta rasm RAM'da ~4 MB. Tarix ekranida 40–50 ta rasm = 150–200 MB → iOS
//     ilovani o'ldiradi. Endi rasm katakcha o'lchamida (~160px, ~0.1 MB) dekod
//     qilinadi (`AppNetworkImage` + `maxDecodeWidth`, lokal fayl uchun `cacheWidth`),
//     to'liq ekran ko'rinishi esa umumiy `FullScreenImagePage` — u yopilganda
//     katta bitmap keshdan chiqariladi.
//
//  2) RO'YXAT — har sklad kartochkasi o'z ichidagi HAMMA qatorni bir yo'la qurardi
//     (ekranda ko'rinmaganini ham): 60 ta mahsulot = 60 ta TextField + 60 ta rasm
//     birdaniga. Endi ro'yxat YASSI (flat): kartochka ko'rinishi saqlangan, lekin
//     har qator alohida ListView elementi — faqat ko'rinib turgani quriladi.
//
//  3) REBUILD — «Kelgan soni» maydoniga har harf yozilganda butun kartochka
//     (hamma qator) qayta qurilardi. Endi faqat kamomad yozuvi yangilanadi
//     (ValueListenableBuilder), boshqa qatorlarga umuman tegilmaydi.
//
// KESH: sahifa xotirada hech narsa yig'maydi — qator holati (kiritilgan son,
// olingan rasm) faqat TAHRIRLANADIGAN qatorlar uchun ochiladi va item qabul
// qilinishi bilan darhol tozalanadi.
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
import 'package:uz_ai_dev/core/widgets/app_network_image.dart';
import 'package:uz_ai_dev/core/widgets/full_screen_image.dart';
import 'package:uz_ai_dev/core/widgets/order_period.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';

const Color _bg = Color(0xFFFAF6F1);
const Color _accent = Color(0xFFC5A97B);
const Color _red = Color(0xFFC62828);
const Color _green = Color(0xFF2E7D32);

// Rasm/Video katakchasi va tugmalar balandligi.
const double _cellH = 48;

// Tarmoq rasmi shu kenglikdan katta dekod qilinmaydi (fizik piksel).
// Katakcha ~55dp, 3x ekranda ~165px — 1024px o'rniga ~40 barobar kam RAM.
const int _thumbMaxDecode = 192;

// Lokal (kameradan olingan) rasm uchun dekod kengligi — fayl 1080p+ bo'lsa ham
// katakcha uchun shuncha yetadi.
int _thumbDecodePx(BuildContext context) =>
    (56 * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 256);

// ─────────────────────────────── Ekranlar ───────────────────────────────

// Ombor o'zi bergan buyurtmalar ekrani (alohida sahifa sifatida).
// Yuk keltiruvchi narxlab qaytarganda status "narxlandi" bo'ladi.
class OmborOrdersUi extends StatelessWidget {
  const OmborOrdersUi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Mening buyurtmalarim',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Faqat davr tugmasi provider'ni kuzatadi — butun ekran emas.
          Selector<OmborProvider, OrderPeriod>(
            selector: (_, p) => p.ordersPeriod,
            builder: (context, period, _) => OrderPeriodButton(
              value: period,
              onChanged: (p) => context.read<OmborProvider>().setOrdersPeriod(p),
            ),
          ),
        ],
      ),
      body: const OmborOrdersView(),
    );
  }
}

// Qabul qilingan buyurtmalar tarixi — bosh ekrandagi AppBar'dagi tarix
// tugmasidan ochiladi. Faqat status "qabul_qilindi" bo'lganlar ko'rinadi.
// Davr tanlagich YO'Q: tarix tanlangan KUNNI serverdan aynan so'raydi
// (GET /api/orders?date=...), ya'ni payload bitta kundan iborat bo'ladi.
class OmborOrdersHistoryUi extends StatelessWidget {
  const OmborOrdersHistoryUi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
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

// ──────────────────────── Ro'yxat (asosiy mazmun) ────────────────────────

// Ombor buyurtmalari ro'yxati — bosh ekrandagi «Buyurtmalarim» tabи ham,
// tarix ekrani ham shuni ishlatadi.
// acceptedOnly=false: hali qabul qilinmagan buyurtmalar (aktivlar).
// acceptedOnly=true: tanlangan kunda qabul qilinganlar (tarix).
class OmborOrdersView extends StatefulWidget {
  final bool acceptedOnly;
  const OmborOrdersView({super.key, this.acceptedOnly = false});

  @override
  State<OmborOrdersView> createState() => _OmborOrdersViewState();
}

class _OmborOrdersViewState extends State<OmborOrdersView> {
  // Tarix ekrani uchun tanlangan kun (standart — bugun).
  DateTime _selectedDate = _todayDate();

  // dispose() ichida context.read() xavfsiz emas — referens saqlanadi.
  OmborProvider? _provider;

  // Qator holati: '<order_id>_<product_id>' -> kiritilgan son + olingan media.
  // FAQAT tahrirlanadigan qatorlar uchun ochiladi; item qabul qilinishi yoki
  // buyurtma yopilishi bilan post-frame'da dispose qilinadi (pastdagi _prune).
  final Map<String, _RowSlot> _slots = {};
  Set<String> _liveKeys = const <String>{};
  bool _pruneScheduled = false;

  // Shu ekranda tarmoq rasmi ko'rsatildimi. Faqat shunda chiqishda rasm keshi
  // bo'shatiladi — rasm ko'rsatilmagan bo'lsa boshqa ekranlarning rasmiga
  // bekorga tegmaymiz.
  bool _usedNetworkImage = false;

  static DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OmborProvider>();
      if (widget.acceptedOnly) {
        provider.fetchHistoryOrders(_selectedDate);
      } else {
        provider.fetchMyOrders();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<OmborProvider>();
  }

  @override
  void dispose() {
    for (final slot in _slots.values) {
      slot.dispose();
    }
    _slots.clear();
    if (widget.acceptedOnly) {
      // Tarix ro'yxati boshqa hech qayerda ishlatilmaydi — xotirada qoldirmaymiz.
      _provider?.clearHistoryOrders();
      // Tarixda o'nlab tarmoq rasmi ko'rsatiladi va ular ImageCache'da qolib
      // ketadi. Tarix ALOHIDA sahifa (tabга emas, orqaga qaytiladi), shuning
      // uchun chiqishda keshni bo'shatish xavfsiz. Aktiv tab'da bunday
      // qilinmaydi: u yerda rasm kam, tab almashganda esa «Mahsulotlar»
      // rasmlarini bekorga qayta dekod qilishga majbur qilardi.
      if (_usedNetworkImage) PaintingBinding.instance.imageCache.clear();
    }
    super.dispose();
  }

  // ───────────────────────── Qator holati (slot) ─────────────────────────

  _RowSlot _slotFor(String key, String initialText) =>
      _slots.putIfAbsent(key, () => _RowSlot(initialText));

  // Ro'yxatdan chiqib ketgan qatorlarning controllerlarini bo'shatish.
  // Build ichida dispose qilib bo'lmaydi (widget hali daraxtda bo'lishi mumkin),
  // shuning uchun kadr chizilgandan keyin tozalanadi.
  void _schedulePrune(Set<String> liveKeys) {
    _liveKeys = liveKeys;
    if (_pruneScheduled) return;
    _pruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pruneScheduled = false;
      if (!mounted) return;
      final stale = _slots.keys.where((k) => !_liveKeys.contains(k)).toList();
      for (final k in stale) {
        _slots.remove(k)?.dispose();
      }
    });
  }

  // ─────────────────────────── Sana navigatsiyasi ───────────────────────────

  Future<void> _refresh() {
    final provider = context.read<OmborProvider>();
    return widget.acceptedOnly
        ? provider.fetchHistoryOrders(_selectedDate)
        : provider.fetchMyOrders();
  }

  String _dateLabelOf(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  bool get _isToday =>
      OmborProvider.dateKeyOf(_selectedDate) ==
      OmborProvider.dateKeyOf(_todayDate());

  // Kun almashtirilganda o'sha kun serverdan so'raladi (xotirada bitta kun).
  void _setDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    setState(() => _selectedDate = day);
    context.read<OmborProvider>().fetchHistoryOrders(day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: _todayDate(),
    );
    if (picked != null) _setDate(picked);
  }

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
                const Icon(Icons.calendar_today, size: 15, color: _accent),
                const SizedBox(width: 8),
                Text(
                  _dateLabelOf(_selectedDate),
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OmborProvider>();

    final loading = widget.acceptedOnly
        ? provider.isLoadingHistory
        : provider.isLoadingOrders;
    if (loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final error =
        widget.acceptedOnly ? provider.historyError : provider.ordersError;
    if (error != null) return _errorView(error);

    // Asosiy tab: server allaqachon faqat qabul qilinmaganlarni yuborgan
    // (?active=1) — filtr himoya qatlami. Tarix: server aynan shu kunni
    // yuborgan (?date=...), qabul qilinganlarini ajratib olamiz.
    final orders = widget.acceptedOnly
        ? provider.historyOrders.where((o) => o.isAccepted).toList()
        : provider.myOrders.where((o) => !o.isAccepted).toList();

    final rows = _buildRows(orders);
    final list = _list(rows, provider);

    if (!widget.acceptedOnly) return list;
    return Column(
      children: [
        const SizedBox(height: 4),
        _dateNav(),
        const Divider(height: 1),
        Expanded(child: list),
      ],
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
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

  // Buyurtmalarni sklad bo'yicha guruhlab, YASSI qatorlar ro'yxatiga aylantirish.
  // Bu yerda faqat yengil obyektlar yasaladi (widget emas) — widget'lar keyin
  // ListView.builder'da faqat ko'rinadigan qatorlar uchun quriladi.
  List<_Row> _buildRows(List<OmborOrder> orders) {
    final groups = <String, List<OmborOrder>>{};
    for (final o in orders) {
      groups.putIfAbsent(o.skladName, () => <OmborOrder>[]).add(o);
    }

    final rows = <_Row>[];
    final liveKeys = <String>{};
    var usedNetworkImage = false;

    for (final entry in groups.entries) {
      // Rasxod (xarajat) itemlari ombor ekranida ko'rsatilmaydi.
      final ordersWithItems = [
        for (final o in entry.value)
          if (o.items.any((it) => !it.isRasxod)) o,
      ];
      if (ordersWithItems.isEmpty) continue;

      rows.add(_HeaderRow(entry.key));
      var first = true;
      for (final order in ordersWithItems) {
        // Bitta kartadagi ikki buyurtma orasida vaqt bilan ajratuvchi.
        if (!first) rows.add(_TimeRow(order.id, _orderTime(order.created)));
        first = false;
        for (final item in order.items) {
          if (item.isRasxod) continue;
          final row = _ItemRow.of(order, item);
          rows.add(row);
          if (row.editable) liveKeys.add(row.slotKey);
          if (!row.editable && item.imageUrl.isNotEmpty) {
            usedNetworkImage = true;
          }
        }
      }
      rows.add(_FooterRow(
        entry.key,
        allAccepted: ordersWithItems.every((o) => o.isAccepted),
      ));
    }

    if (usedNetworkImage) _usedNetworkImage = true;
    _schedulePrune(liveKeys);
    return rows;
  }

  Widget _list(List<_Row> rows, OmborProvider provider) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        color: _accent,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long, size: 56, color: Colors.grey),
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

    return RefreshIndicator(
      color: _accent,
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: rows.length,
        // Har element o'z kaliti bilan — ro'yxat yangilanganda TextField'lar
        // bir-birining o'rniga tushib qolmasligi uchun.
        itemBuilder: (context, index) => _rowWidget(rows[index], provider),
      ),
    );
  }

  Widget _rowWidget(_Row row, OmborProvider provider) {
    switch (row) {
      case _HeaderRow():
        return _CardShell(
          key: ValueKey(row.key),
          top: true,
          child: _GroupHeader(skladName: row.skladName),
        );
      case _TimeRow():
        return _CardShell(
          key: ValueKey(row.key),
          child: _OrderSeparator(time: row.time),
        );
      case _FooterRow():
        return _CardShell(
          key: ValueKey(row.key),
          bottom: true,
          child: row.allAccepted
              ? const _AcceptedBadge()
              : const SizedBox.shrink(),
        );
      case _ItemRow():
        return _CardShell(
          key: ValueKey(row.key),
          child: _itemView(row, provider),
        );
    }
  }

  Widget _itemView(_ItemRow row, OmborProvider provider) {
    final item = row.item;
    if (item.deleted) return _DeletedItemView(item: item);

    // Slot faqat tahrirlanadigan qator uchun (kiritish maydoni + media).
    final slot = row.editable ? _slotFor(row.slotKey, row.initialQty) : null;

    return _ItemView(
      item: item,
      editable: row.editable,
      notBrought: row.notBrought,
      deletable: row.deletable,
      slot: slot,
      isAccepting: provider.acceptingItemOrderId == row.order.id &&
          provider.acceptingItemProductId == item.productId,
      isDeleting: provider.deletingItemOrderId == row.order.id &&
          provider.deletingItemProductId == item.productId,
      onTapMedia: () => _pickMedia(row.slotKey),
      onAccept: () => _acceptItem(row),
      onDelete: () => _deleteItem(row),
    );
  }

  // ──────────────────────────── Media olish ────────────────────────────

  // Kamera katakchasi bosilganda: "Rasm olish" yoki "Video olish" tanlovi.
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

  // Rasm olish — ilova ICHIDAGI kamera (InAppPhotoCamera). image_picker'ning
  // tashqi kamerasi Android'da ilovani orqa fonda o'ldirib, kiritilgan
  // "Kelgan soni" qiymatlarini yo'qotardi.
  Future<void> _captureImage(String key) async {
    final x = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => const InAppPhotoCamera()),
    );
    if (x == null || !mounted) return;
    // setState YO'Q — faqat shu katakcha qayta chiziladi.
    _slots[key]?.media.value = _LocalMedia(imagePath: x.path);
  }

  // Aylana (Telegram video note uslubi) video yozish.
  Future<void> _captureVideo(String key) async {
    final segments = await Navigator.of(context).push<List<XFile>>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => const TelegramStyleVideoRecorder(),
      ),
    );
    if (segments == null || segments.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    _showProcessingDialog();
    try {
      // Kvadrat (1:1) qirqib, 480p ga siqamiz — kichik hajm, sifat saqlanadi.
      final processedPath = await VideoProcessor.toSquareNote(
        segments.map((e) => e.path).toList(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _slots[key]?.media.value = _LocalMedia(videoPath: processedPath);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      // Siqilmasa ham video yuborilsin — xom birinchi segment ishlatiladi.
      _slots[key]?.media.value = _LocalMedia(videoPath: segments.first.path);
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

  // ─────────────────────── Qabul qilish / o'chirish ───────────────────────

  // Bitta mahsulotni qabul qilish: kelgan soni + rasm/video yuboriladi.
  // Rasm ham video ham bo'lmasa yuborilmaydi (kamida bittasi majburiy).
  Future<void> _acceptItem(_ItemRow row) async {
    final order = row.order;
    final item = row.item;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OmborProvider>();
    final slot = _slots[row.slotKey];

    final media = slot?.media.value ?? const _LocalMedia();
    // Yangi media majburiy — itemda avvaldan saqlangan rasm/video bo'lmasa.
    final hasExistingMedia =
        item.imageUrl.isNotEmpty || item.videoUrl.isNotEmpty;
    if (media.isEmpty && !hasExistingMedia) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Avval rasm yoki video oling')),
      );
      return;
    }

    // Maydonda UI birlik (kg/l) — API'ga butun gramm/ml yuboriladi.
    // qtyFromUiSafe: 1000+ kiritilsa gramm deb olinadi (gramm-yozish himoyasi).
    final received = slot == null
        ? 0.0
        : qtyFromUiSafe(_parseQty(slot.received.text), item.type).toDouble();

    // Kelgan soni kiritilmagan yoki 0 bo'lsa qabul yuborilmaydi.
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
                backgroundColor: _accent,
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
        media.imagePath,
        media.videoPath,
      );
      // Yuborilgan lokal fayllar endi kerak emas (backend URL qaytardi).
      // Slot shu orada tozalangan bo'lishi mumkin — map orqali qaytadan olamiz.
      _slots[row.slotKey]?.media.value = const _LocalMedia();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Bitta mahsulotni buyurtmadan o'chirish (tasdiq dialogi bilan).
  Future<void> _deleteItem(_ItemRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OmborProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mahsulotni o\'chirish',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text('"${row.item.name}" buyurtmadan o\'chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await provider.deleteOrderItem(row.order.id, row.item.productId);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ─────────────────────────── Qator modellari ───────────────────────────

// Yassi ro'yxat elementi. Widget emas — yengil ma'lumot obyekti.
sealed class _Row {
  const _Row();

  // ListView elementi kaliti (element qayta ishlatilganda aralashmasin).
  String get key;
}

// Kartochka boshi: sklad nomi + jadval sarlavhasi.
class _HeaderRow extends _Row {
  final String skladName;
  const _HeaderRow(this.skladName);

  @override
  String get key => 'h:$skladName';
}

// Bitta kartadagi ikki buyurtma orasidagi vaqt ajratuvchisi.
class _TimeRow extends _Row {
  final int orderId;
  final String time;
  const _TimeRow(this.orderId, this.time);

  @override
  String get key => 't:$orderId';
}

// Kartochka oxiri (+ hammasi qabul qilingan bo'lsa yashil belgi).
class _FooterRow extends _Row {
  final String skladName;
  final bool allAccepted;
  const _FooterRow(this.skladName, {required this.allAccepted});

  @override
  String get key => 'f:$skladName';
}

// Mahsulot qatori — o'z buyurtmasi bilan bog'langan. Ko'rinish bayroqlari
// bir marta (ro'yxat yasalayotganda) hisoblanadi, har build'da emas.
class _ItemRow extends _Row {
  final OmborOrder order;
  final OmborOrderItem item;
  // Son/media kiritiladi va qabul tugmasi ko'rinadi.
  final bool editable;
  // Yuk keltiruvchi umuman olib kelmagan (taken 0, summa 0) — «Olinmagan».
  final bool notBrought;
  // Omborchi itemni buyurtmadan o'chira oladimi.
  final bool deletable;

  const _ItemRow._({
    required this.order,
    required this.item,
    required this.editable,
    required this.notBrought,
    required this.deletable,
  });

  factory _ItemRow.of(OmborOrder order, OmborOrderItem item) {
    // Narxlangan buyurtmada olib kelinmagan mahsulot (taken 0, summa 0)
    // qabul qilinmaydi.
    final notTaken = order.isPriced && item.taken <= 0 && item.subtotal <= 0;
    final editable =
        !order.isAccepted && !item.accepted && !item.deleted && !notTaken;
    // O'chirish: faqat katalog item (proche/rasxod emas), hali kelmagan va
    // order yopilmagan. Yopiq (narxlandi) chekda faqat summasiz item —
    // qolgani ledgerga tushgan.
    final deletable = !order.isAccepted &&
        !item.accepted &&
        !item.deleted &&
        item.itemType.isEmpty &&
        (order.isCreated || item.subtotal <= 0) &&
        item.received <= 0;
    return _ItemRow._(
      order: order,
      item: item,
      editable: editable,
      notBrought: !order.isCreated &&
          !item.accepted &&
          item.taken <= 0 &&
          item.subtotal <= 0,
      deletable: deletable,
    );
  }

  // Kalit KOMPOZIT: bir kartada bir nechta buyurtma bo'lgani uchun bir xil
  // product_id turli buyurtmalarda uchrashi mumkin.
  String get slotKey => '${order.id}_${item.productId}';

  @override
  String get key => 'i:$slotKey';

  // "Kelgan soni" maydonining boshlang'ich qiymati: narxlangan buyurtmada
  // yuk keltiruvchi aytgan miqdor (taken), narxlanmaganda BO'SH.
  String get initialQty =>
      order.isPriced ? formatQty(item.taken, item.type) : '';
}

// Tahrirlanadigan qator holati: kiritilgan son + olingan lokal media.
class _RowSlot {
  _RowSlot(String initialText)
      : received = TextEditingController(text: initialText);

  final TextEditingController received;
  final ValueNotifier<_LocalMedia> media =
      ValueNotifier<_LocalMedia>(const _LocalMedia());

  void dispose() {
    received.dispose();
    media.dispose();
  }
}

// Hali yuborilmagan lokal rasm/video yo'li.
class _LocalMedia {
  final String? imagePath;
  final String? videoPath;
  const _LocalMedia({this.imagePath, this.videoPath});

  bool get isEmpty => imagePath == null && videoPath == null;
}

// ────────────────────────────── Vidjetlar ──────────────────────────────

// Kartochka bo'lagi: qatorlar alohida ListView elementi bo'lsa ham, ustma-ust
// tushib bitta oq kartochkaga o'xshaydi (tepasi/pastki burchagi yumaloq).
class _CardShell extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  const _CardShell({
    super.key,
    required this.child,
    this.top = false,
    this.bottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: top ? 6 : 0,
        bottom: bottom ? 6 : 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(top ? 14 : 0),
            bottom: Radius.circular(bottom ? 14 : 0),
          ),
        ),
        padding: EdgeInsets.fromLTRB(14, top ? 14 : 0, 14, bottom ? 14 : 0),
        child: child,
      ),
    );
  }
}

// Kartochka sarlavhasi: sklad nomi + jadval sarlavhasi (order_id ko'rsatilmaydi).
class _GroupHeader extends StatelessWidget {
  final String skladName;
  const _GroupHeader({required this.skladName});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.store_outlined, size: 18, color: _accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                skladName.isEmpty ? 'Buyurtma' : skladName,
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
        const Padding(
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
                child:
                    Text('Qabul', textAlign: TextAlign.center, style: style),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Ikki buyurtma orasidagi ingichka ajratuvchi — o'rtasida buyurtma vaqti.
class _OrderSeparator extends StatelessWidget {
  final String time;
  const _OrderSeparator({required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: Colors.grey.shade300)),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 3),
            Text(time,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(width: 8),
            Expanded(child: Divider(height: 1, color: Colors.grey.shade300)),
          ],
        ],
      ),
    );
  }
}

// Kartochka oxiridagi «Qabul qilindi» belgisi (tarix ekranida).
class _AcceptedBadge extends StatelessWidget {
  const _AcceptedBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 18, color: _green),
            SizedBox(width: 6),
            Text(
              'Qabul qilindi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// O'chirilgan item: nom + miqdor qizil chizilgan, o'ng tomonda «O'chirildi».
class _DeletedItemView extends StatelessWidget {
  final OmborOrderItem item;
  const _DeletedItemView({required this.item});

  @override
  Widget build(BuildContext context) {
    const deletedStyle = TextStyle(
      color: Colors.red,
      decoration: TextDecoration.lineThrough,
      decorationColor: Colors.red,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
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
                Text(
                  _qtyLabel(item),
                  style: deletedStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 7,
            child: Container(
              height: _cellH,
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
}

// Mahsulot qatori: nom + farq | «Kelgan soni» | Rasm/Video | Qabul.
class _ItemView extends StatelessWidget {
  final OmborOrderItem item;
  final bool editable;
  final bool notBrought;
  final bool deletable;
  final _RowSlot? slot;
  final bool isAccepting;
  final bool isDeleting;
  final VoidCallback onTapMedia;
  final VoidCallback onAccept;
  final VoidCallback onDelete;

  const _ItemView({
    required this.item,
    required this.editable,
    required this.notBrought,
    required this.deletable,
    required this.slot,
    required this.isAccepting,
    required this.isDeleting,
    required this.onTapMedia,
    required this.onAccept,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 5, child: _nameCell()),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: _qtyCell()),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _mediaCell(context)),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _acceptCell()),
        ],
      ),
    );
  }

  // Nom + buyurtma soni + (ortiqcha/kam) farq + o'chirish ikonkasi.
  // Omborchi narx ko'rmaydi — birlik narx qatori ataylab yo'q.
  Widget _nameCell() {
    final diff = item.taken - item.count;
    // Proche (yuk keltiruvchi qo'shgan) mahsulotda buyurtma soni yo'q.
    final showDiff = !item.isProche && item.taken > 0 && diff.abs() > 0.0001;
    final unit = item.type.isNotEmpty ? ' ${item.type}' : '';

    return Row(
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
                    _qtyLabel(item),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (showDiff) ...[
                    const SizedBox(width: 6),
                    Text(
                      diff > 0
                          ? '+${formatQty(diff, item.type)}$unit'
                          : '-${formatQty(diff.abs(), item.type)}$unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: diff > 0 ? _green : _red,
                      ),
                    ),
                  ],
                ],
              ),
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
                          strokeWidth: 2, color: _red),
                    )
                  : const Icon(Icons.delete_outline, size: 19, color: _red),
            ),
          ),
      ],
    );
  }

  // «Kelgan soni» + kamomad belgisi.
  //
  // Kamomad yozuvi kiritilgan songa bog'liq, shuning uchun U FAQAT O'ZI
  // ValueListenableBuilder ichida yangilanadi — har harfda butun ro'yxat
  // (oldin butun kartochka) qayta qurilmaydi.
  Widget _qtyCell() {
    if (!editable || slot == null) {
      return Column(
        children: [
          _receivedView(),
          _shortageText(item.received),
        ],
      );
    }
    return Column(
      children: [
        TextField(
          controller: slot!.received,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
            // Kiritilayotgan son yonida birlik ("kg") ko'rinib turadi.
            suffixText: item.type.isNotEmpty ? item.type : null,
            suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: slot!.received,
          builder: (context, value, _) => _shortageText(
            qtyFromUiSafe(_parseQty(value.text), item.type).toDouble(),
          ),
        ),
      ],
    );
  }

  // Kelgan soni (haqiqatda kelgan) va taken (yuk keltiruvchi aytgan) farqi:
  // >0 = kam kelgan (kamomad, qizil), <0 = ortiq kelgan (yashil).
  Widget _shortageText(double received) {
    final shortage = item.taken - received;
    if (item.taken <= 0 || received <= 0 || shortage.abs() <= 0.0001) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        shortage > 0
            ? '-${formatQty(shortage, item.type)}'
            : '+${formatQty(shortage.abs(), item.type)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: shortage > 0 ? _red : _green,
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

  // Rasm/Video katakchasi.
  //
  // ⚠️ RASM O'LCHAMI — shu ekranning eng muhim joyi. Katakcha ~55dp, lekin
  // fayl 1024px (server) yoki 1080p+ (kamera). O'lchamsiz dekod qilinsa bitta
  // rasm RAM'da ~4 MB egallaydi va ro'yxatdagi o'nlab rasm ilovani o'ldiradi.
  // Shuning uchun: tarmoq rasmi — AppNetworkImage (memCacheWidth ≤ 192px),
  // lokal fayl — Image.file(cacheWidth: ...).
  Widget _mediaCell(BuildContext context) {
    if (editable && slot != null) {
      return ValueListenableBuilder<_LocalMedia>(
        valueListenable: slot!.media,
        builder: (context, media, _) {
          if (media.imagePath != null) {
            return _MediaThumb(
              onTap: onTapMedia,
              child: Image.file(
                File(media.imagePath!),
                fit: BoxFit.cover,
                cacheWidth: _thumbDecodePx(context),
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 18, color: Colors.grey),
              ),
            );
          }
          if (media.videoPath != null) {
            return _MediaBox(
                icon: Icons.videocam, filled: true, onTap: onTapMedia);
          }
          return _MediaBox(
              icon: Icons.photo_camera_outlined, onTap: onTapMedia);
        },
      );
    }

    if (item.imageUrl.isNotEmpty) {
      final url = '${AppUrls.baseUrl}${item.imageUrl}';
      return _MediaThumb(
        onTap: () => openFullScreenImage(context, url),
        child: AppNetworkImage(
          imageUrl: url,
          maxDecodeWidth: _thumbMaxDecode,
        ),
      );
    }

    if (item.videoUrl.isNotEmpty) {
      return _MediaBox(
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

  // Qabul katakchasi: tahrirlanadigan qatorda yashil tugma (yuborishda
  // spinner), qabul qilinganda yashil belgi, olib kelinmaganda «Olinmagan».
  Widget _acceptCell() {
    if (notBrought) {
      return Container(
        height: _cellH,
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
      return Container(
        height: _cellH,
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
        child: SizedBox(
          height: _cellH,
          child: Center(
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
      ),
    );
  }
}

// Rasm/Video olish tugmasi — faqat ikonka (quti ko'rinishida).
class _MediaBox extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  const _MediaBox({required this.icon, this.filled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _green.withValues(alpha: 0.10) : const Color(0xFFF5F1EA),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: _cellH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  filled ? _green.withValues(alpha: 0.4) : Colors.grey.shade300,
            ),
          ),
          child: Icon(icon, size: 20, color: filled ? _green : Colors.grey.shade600),
        ),
      ),
    );
  }
}

// Rasm thumbnaili (lokal yoki tarmoq).
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
        child: SizedBox(height: _cellH, width: double.infinity, child: child),
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
      height: _cellH,
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

// ────────────────────────────── Yordamchilar ──────────────────────────────

// "3 кг" / "Qo'shimcha" (proche mahsulotda buyurtma soni yo'q).
String _qtyLabel(OmborOrderItem item) => item.isProche
    ? 'Qo\'shimcha'
    : '${formatQty(item.count, item.type)}'
        '${item.type.isNotEmpty ? ' ${item.type}' : ''}';

// "2026-06-20T12:34:..." -> "12:34".
String _orderTime(String created) {
  final t = created.indexOf('T');
  if (t == -1) return '';
  final rest = created.substring(t + 1);
  return rest.length >= 5 ? rest.substring(0, 5) : rest;
}

// "Kelgan soni" matnini songa aylantirish (vergul -> nuqta).
double _parseQty(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}
