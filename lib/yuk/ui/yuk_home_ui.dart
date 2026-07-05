import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_history_ui.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_profile_ui.dart';

// Sklad nomlari (loyihaning boshqa joylarida ham shu hardcode map ishlatiladi).
const Map<int, String> kSkladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
};

// Raqam maydonida ming ajratuvchi sifatida har 3 xonadan keyin oddiy probel
// qo'yadigan formatter: 3000 -> "3 000", 1500000 -> "1 500 000".
// Faqat butun son (raqamlar). Kursor doim oxirida turadi.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Faqat raqamlarni qoldiramiz (probel va boshqa belgilarni olib tashlaymiz).
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // O'ngdan 3 xonadan guruhlab oddiy probel qo'shamiz.
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// kg bilan o'lchanadigan mahsulotlar uchun: raqamlar va bitta o'nlik
// ajratuvchi (nuqta yoki vergul) ga ruxsat. Masalan "8.500", "8,5".
class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    // Faqat raqamlar va eng ko'pi bilan bitta nuqta/vergul.
    if (!RegExp(r'^[0-9]*[.,]?[0-9]*$').hasMatch(text)) {
      return oldValue;
    }
    return newValue;
  }
}

// Yuk keltiruvchi roli uchun bosh ekran.
// Foydalanuvchiga biriktirilgan skladlar bo'yicha tablar; har tabда
// o'sha skladning buyurtmalari (FAQAT ko'rish).
class YukHomeUi extends StatefulWidget {
  const YukHomeUi({super.key});

  @override
  State<YukHomeUi> createState() => _YukHomeUiState();
}

class _YukHomeUiState extends State<YukHomeUi> {
  final TokenStorage tokenStorage = sl<TokenStorage>();

  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  List<int> _sklads = [];
  bool _loadingSklads = true;

  // dispose() ichida context.read() xavfsiz emas (widget deaktiv bo'lishi mumkin),
  // shuning uchun provider referensini didChangeDependencies'da saqlaymiz.
  YukProvider? _yukProvider;

  @override
  void initState() {
    super.initState();
    _loadSklads();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<YukProvider>();
      // Avval lokal qoralamalarni tiklaymiz (internet o'chiq bo'lsa ham
      // kiritilgan narxlar yo'qolmasin), keyin serverdan ro'yxatni olamiz.
      await provider.loadDrafts();
      await provider.fetchOrders();
      // Real-time: narxlash/buyurtma o'zgarishlari refresh'siz ko'rinishi uchun.
      provider.connectSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _yukProvider = context.read<YukProvider>();
  }

  @override
  void dispose() {
    // Ekrandan chiqishda real-time ulanishni uzamiz (saqlangan referens orqali).
    _yukProvider?.disconnectSocket();
    super.dispose();
  }

  // SharedPreferences'dagi 'user' JSON ichidan `sklads` ro'yxatini o'qish.
  Future<void> _loadSklads() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    final sklads = <int>[];
    if (userStr != null && userStr.isNotEmpty) {
      try {
        final user = jsonDecode(userStr);
        if (user is Map && user['sklads'] is List) {
          for (final s in user['sklads']) {
            if (s is int) {
              sklads.add(s);
            } else if (s is num) {
              sklads.add(s.toInt());
            } else {
              final parsed = int.tryParse(s.toString());
              if (parsed != null) sklads.add(parsed);
            }
          }
        }
      } catch (_) {
        // noto'g'ri JSON bo'lsa bo'sh ro'yxat bilan davom etamiz
      }
    }
    if (!mounted) return;
    setState(() {
      _sklads = sklads;
      _loadingSklads = false;
    });
  }

  void _logout() {
    // Logout: avval socketni uzamiz.
    context.read<YukProvider>().disconnectSocket();
    tokenStorage.removeToken();
    tokenStorage.removeRefreshToken();
    context.push(LoginPage());
  }

  String _skladName(int id) => kSkladNames[id] ?? 'Sklad $id';

  @override
  Widget build(BuildContext context) {
    if (_loadingSklads) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    // Foydalanuvchida sklad bo'lmasa.
    if (_sklads.isEmpty) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: _buildAppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sizga hech qanday sklad biriktirilmagan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: _sklads.length,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: _buildAppBar(
          bottom: TabBar(
            isScrollable: _sklads.length > 2,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.black54,
            indicatorColor: _accentColor,
            tabs: _sklads.map((id) => Tab(text: _skladName(id))).toList(),
          ),
        ),
        // Bo'sh joyga (maydonlardan tashqari) bosilsa klaviatura yopiladi.
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Consumer<YukProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (provider.errorMessage != null) {
              return _ErrorView(
                message: provider.errorMessage!,
                onRetry: () => provider.fetchOrders(),
              );
            }

            return Column(
              children: [
                // Internet yo'q paytda ko'rsatiladigan eslatma. Ro'yxat oxirgi
                // saqlangan keshdan, kiritilgan narxlar lokal saqlanadi.
                if (provider.isOffline) const _OfflineBanner(),
                Expanded(
                  child: TabBarView(
                    children: _sklads.map((id) {
                      // Asosiy sahifada faqat hali yuborilmagan buyurtmalar
                      // (yuborilganlar AppBar'dagi tarix ekranida).
                      final orders = provider.pendingForSklad(id);
                      return RefreshIndicator(
                        onRefresh: () => provider.fetchOrders(),
                        child: orders.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Buyurtmalar yo\'q',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: orders.length,
                                itemBuilder: (context, index) => YukOrderCard(
                                  // Ro'yxatdan karta chiqib ketganda (yuborilib
                                  // tarixga o'tganda) state adashmasligi uchun.
                                  key: ValueKey(orders[index].id),
                                  order: orders[index],
                                ),
                              ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({PreferredSizeWidget? bottom}) {
    return AppBar(
      backgroundColor: _bgColor,
      elevation: 0,
      title: const Text(
        'Yuk keltiruvchi',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      actions: [
        // Yuborilgan buyurtmalar tarixi.
        IconButton(
          onPressed: () => context.push(YukHistoryUi(sklads: _sklads)),
          icon: const Icon(Icons.history),
          tooltip: 'Yuborilganlar tarixi',
        ),
        IconButton(
          onPressed: () => context.push(YukProfileUi(sklads: _sklads)),
          icon: const Icon(Icons.person_outline),
          tooltip: 'Profil',
        ),
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      bottom: bottom,
    );
  }
}

// Internet yo'q paytdagi yupqa eslatma chizig'i.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 16, color: Color(0xFFB26A00)),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Internet yo\'q — narxlar telefonда saqlanmoqda, ulanish '
              'tiklanganda yuboriladi',
              style: TextStyle(fontSize: 12, color: Color(0xFFB26A00)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
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
}

// Summalarni chiroyli ko'rsatish: 1000 -> "1 000".
String _formatMoney(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

// Bitta buyurtma kartasi: order_id, ombor nomi (username), sana, items.
// Har item qatorida INLINE maydonlar (Nechta olgani / Jami summa),
// pastida "Chek bilan yuborish" tugmasi.
// Public — tarix ekrani (yuk_history_ui.dart) ham shu kartani ishlatadi.
class YukOrderCard extends StatefulWidget {
  final YukOrder order;
  const YukOrderCard({super.key, required this.order});

  @override
  State<YukOrderCard> createState() => _YukOrderCardState();
}

class _YukOrderCardState extends State<YukOrderCard> {
  static const Color _accentColor = Color(0xFFC5A97B);

  // Har bir item (product_id) uchun olingan miqdor va jami summa controllerlari.
  final Map<int, TextEditingController> _takenControllers = {};
  final Map<int, TextEditingController> _subtotalControllers = {};

  // Har bir item (product_id) uchun "Nechta olgani" maydonining FocusNode'i.
  final Map<int, FocusNode> _takenFocusNodes = {};

  // Rasm/video tanlash uchun (kamera va galereya).
  final ImagePicker _picker = ImagePicker();

  // "Qaytarib olish" oynasi sanog'ini har soniyada yangilab turuvchi timer.
  Timer? _undoTicker;

  YukOrder get order => widget.order;

  // Buyurtma yuk keltiruvchi tomonidan narxlanib yuborilganmi (yoki omborchi
  // qabul qilganmi). Bunda maydonlar faqat ko'rish uchun (read-only) bo'ladi.
  bool get _isDone =>
      order.status == 'narxlandi' || order.status == 'qabul_qilindi';

  // Mavjud qiymatni controllerga ming ajratuvchili probel bilan to'ldirish:
  // 3000 -> "3 000". Bo'sh/0 bo'lsa bo'sh string.
  String _fmt(double v) {
    if (v == 0) return '';
    return _formatMoney(v);
  }

  // "Nechta olgani" / miqdor uchun: 3 xonagacha yaxlitlab, ortiqcha nollarni
  // olib tashlaydi (8.5 -> "8.5", 8 -> "8", 0.2999999 -> "0.3").
  String _fmtQty(double v) {
    if (v == 0) return '';
    var s = v.toStringAsFixed(3);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  // Mahsulot kg (vazn) bilan o'lchanadimi — 'type' maydoniga qarab.
  // "kg", "кг" (lotin/kirill) ni qamrab oladi.
  bool _isKg(String? type) {
    if (type == null) return false;
    final t = type.toLowerCase();
    return t.contains('kg') || t.contains('кг');
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<YukProvider>();
    for (final item in order.items) {
      // Avval shu sessiyada kiritilgan qiymat, bo'lmasa backenddan kelgan
      // (yuborilgan) qiymat ko'rsatiladi. Omborchi qabul qilgan itemda
      // "olingan miqdor" QULFLANGAN — omborchi kiritgan kelgan soni
      // ko'rsatiladi (lokal qoralama e'tiborga olinmaydi).
      final existing = provider.getItemPrice(order.id, item.productId);
      final taken0 = item.accepted
          ? (item.received > 0 ? item.received : item.taken)
          : (existing?.taken ?? item.taken);
      final subtotal0 = existing?.subtotal ?? item.subtotal;
      _takenControllers[item.productId] =
          TextEditingController(text: _fmtQty(taken0));
      _subtotalControllers[item.productId] =
          TextEditingController(text: _fmt(subtotal0));
      _takenFocusNodes[item.productId] = FocusNode();
      // Qaytarib olingan (pending bo'lib qolgan) buyurtmada oldingi qiymatlar
      // qayta yuborilishi uchun lokal narxga tiklab qo'yamiz.
      // proche/rasxod itemlar bunga kirmaydi — ular added_items orqali ketadi.
      if (!_isDone &&
          existing == null &&
          item.itemType.isEmpty &&
          (taken0 > 0 || subtotal0 > 0)) {
        provider.seedItemPrice(order.id, item.productId, taken0, subtotal0);
      }
    }
    // Qaytarib olingan buyurtmaning serverda qolgan biriktirmalarini lokal
    // ro'yxatga tiklaymiz (qayta yuborishda yo'qolmasligi uchun).
    if (!_isDone && order.attachments.isNotEmpty) {
      provider.seedAttachments(order.id, order.attachments);
    }
    // Qaytarib olingan buyurtmaning proche/rasxod itemlarini lokal qo'shilgan
    // yozuvlar ro'yxatiga tiklaymiz (qayta yuborishda yo'qolmasligi uchun).
    if (!_isDone) {
      provider.seedAddedItems(order.id, order.items);
    }
    _maybeStartUndoTicker();
  }

  // Buyurtma hozir yuborilgan va qaytarib olish oynasi ochiq bo'lsa, sanoqni
  // har soniyada yangilab turamiz; muddat tugashi bilan timer to'xtaydi.
  void _maybeStartUndoTicker() {
    final provider = context.read<YukProvider>();
    if (!_isDone || provider.undoRemaining(order.id) == Duration.zero) return;
    _undoTicker?.cancel();
    _undoTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {});
      if (context.read<YukProvider>().undoRemaining(order.id) ==
          Duration.zero) {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _undoTicker?.cancel();
    for (final c in _takenControllers.values) {
      c.dispose();
    }
    for (final c in _subtotalControllers.values) {
      c.dispose();
    }
    for (final f in _takenFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // Controllerlarni kerak bo'lganda yaratish: buyurtma yuborilgach serverdan
  // yangi (proche/rasxod) itemlar kelsa, initState'da yaratilmagan bo'ladi —
  // null crash bo'lmasligi uchun shu yerda hosil qilamiz.
  TextEditingController _takenCtrlFor(YukOrderItem item) =>
      _takenControllers.putIfAbsent(
        item.productId,
        () => TextEditingController(text: _fmtQty(item.taken)),
      );

  TextEditingController _subtotalCtrlFor(YukOrderItem item) =>
      _subtotalControllers.putIfAbsent(
        item.productId,
        () => TextEditingController(text: _fmt(item.subtotal)),
      );

  FocusNode _takenFocusFor(YukOrderItem item) =>
      _takenFocusNodes.putIfAbsent(item.productId, () => FocusNode());

  // Bo'sh yoki noto'g'ri bo'lsa 0 qaytaradi.
  double _parse(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null || v < 0) return 0;
    return v;
  }

  // Omborchi qabul qilgan itemning qulflangan kelgan soni. Qabul qilinmagan
  // bo'lsa null — qiymat maydondан (controller) olinadi.
  double? _lockedTaken(YukOrderItem item) {
    if (!item.accepted) return null;
    return item.received > 0 ? item.received : item.taken;
  }

  void _onItemChanged(YukOrderItem item) {
    final provider = context.read<YukProvider>();
    final productId = item.productId;
    // Qulflangan itemda taken har doim omborchi kiritgan son — controllerdagi
    // eski/bo'sh qiymatga bog'lanmaydi (faqat summa yozilsa ham 1* narx chiqadi).
    final taken = _lockedTaken(item) ??
        _parse(_takenControllers[productId]?.text ?? '');
    final subtotal = _parse(_subtotalControllers[productId]?.text ?? '');
    provider.setItemPrice(order.id, productId, taken, subtotal);
  }

  String _formatCount(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }

  // ─────────────────── Biriktirmalar (rasm/video) ───────────────────

  // Fayl/URL video ekanini kengaytmasidan aniqlash.
  static bool _isVideoPath(String p) {
    final ext = p.split('.').last.toLowerCase();
    return const {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'}
        .contains(ext);
  }

  // Relativ /static/... URL'ni to'liq manzilga aylantirish.
  static String _fullUrl(String url) =>
      url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';

  Future<void> _pickFromCamera({required bool video}) async {
    try {
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.camera);
      if (file == null || !mounted) return;
      context.read<YukProvider>().addAttachments(order.id, [file.path]);
    } catch (_) {
      // Ruxsat berilmagan/bekor qilingan — jim.
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      // Galereyadan bir nechta rasm/video birga tanlash mumkin.
      final List<XFile> files = await _picker.pickMultipleMedia();
      if (files.isEmpty || !mounted) return;
      context
          .read<YukProvider>()
          .addAttachments(order.id, files.map((f) => f.path).toList());
    } catch (_) {
      // Ruxsat berilmagan/bekor qilingan — jim.
    }
  }

  // Rasm/video qo'shish manbasini tanlash oynasi.
  void _showAddAttachmentSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: _accentColor),
              title: const Text('Kamera — rasm'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromCamera(video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: _accentColor),
              title: const Text('Kamera — video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromCamera(video: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _accentColor),
              title: const Text('Galereya (rasm/video)'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────── Qo'shimcha yozuv (proche mahsulot / rasxod) qo'shish ───────────

  // Bottom sheet: proche mahsulot (nomi + soni + jami summa) yoki rasxod
  // (nomi + jami summa) qo'shish. Saqlashda provider'ga yoziladi.
  void _showAddEntrySheet({required bool rasxod}) {
    FocusScope.of(context).unfocus();
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final sumController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rasxod ? 'Xarajat qo\'shish' : 'Mahsulot qo\'shish',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rasxod
                  ? 'Masalan: yetkazib berish xizmati. Ombor qabul qilmaydi, '
                      'chek oxirida alohida ko\'rsatiladi.'
                  : 'Buyurtmada yo\'q qo\'shimcha mahsulot (masalan gaz plitasi).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nomi',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accentColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!rasxod) ...[
              TextField(
                controller: qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Soni',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accentColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: sumController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Jami summa',
                suffixText: 'so\'m',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final subtotal = _parse(sumController.text);
                  final taken = rasxod ? 0.0 : _parse(qtyController.text);
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Nomini kiriting')),
                    );
                    return;
                  }
                  if (subtotal <= 0) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Summani kiriting')),
                    );
                    return;
                  }
                  context.read<YukProvider>().addAddedItem(
                        order.id,
                        YukAddedItem(
                          itemType: rasxod ? 'rasxod' : 'proche',
                          name: name,
                          taken: rasxod ? 0 : (taken > 0 ? taken : 1),
                          subtotal: subtotal,
                        ),
                      );
                  Navigator.pop(sheetContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Qo\'shish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Qo'shilgan qiymatni ko'rsatadigan kulrang quti (o'chirilgan maydonga o'xshash).
  Widget _addedValueBox(String text) {
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
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }

  // Qo'shilgan proche mahsulot qatori (itemlar jadvali ichida, o'chirish bilan).
  Widget _addedProcheRow(YukProvider provider, int index, YukAddedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: _nameFlex,
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
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Qo\'shimcha',
                        style: TextStyle(
                          fontSize: 12,
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.removeAddedItem(order.id, index),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child:
                        Icon(Icons.close, size: 16, color: Color(0xFFC62828)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _qtyFlex,
            child: _addedValueBox(_fmtQty(item.taken)),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _sumFlex,
            child: _addedValueBox(_formatMoney(item.subtotal)),
          ),
        ],
      ),
    );
  }

  // "Xarajatlar" bloki: rasxod yozuvlari (nomi + summa). Pending'da lokal
  // ro'yxatdan (o'chirish mumkin), yuborilganда serverdagi itemlardan.
  Widget _buildRasxodBlock(YukProvider provider) {
    final rows = <Widget>[];
    if (_isDone) {
      for (final item in order.items.where((i) => i.isRasxod)) {
        rows.add(_rasxodRow(item.name, item.subtotal));
      }
    } else {
      final added = provider.addedItemsFor(order.id);
      for (var i = 0; i < added.length; i++) {
        if (!added[i].isRasxod) continue;
        final index = i;
        rows.add(_rasxodRow(
          added[i].name,
          added[i].subtotal,
          onRemove: () => provider.removeAddedItem(order.id, index),
        ));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 18),
        const Text(
          'Xarajatlar',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  Widget _rasxodRow(String name, double subtotal, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Text(
            '${_formatMoney(subtotal)} so\'m',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 16, color: Color(0xFFC62828)),
              ),
            ),
        ],
      ),
    );
  }

  // Rasmni to'liq ekranda ko'rish; video tashqi pleerda ochiladi.
  void _openAttachment(String entry) {
    final isRemote = YukProvider.isRemoteAttachment(entry);
    if (_isVideoPath(entry)) {
      if (isRemote) {
        launchUrl(Uri.parse(_fullUrl(entry)),
            mode: LaunchMode.externalApplication);
      }
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: isRemote
                    ? Image.network(_fullUrl(entry))
                    : Image.file(File(entry)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bitta biriktirma plitkasi (72x72): rasm — thumbnail, video — play belgisi.
  Widget _attachmentTile(String entry, {VoidCallback? onRemove}) {
    final isRemote = YukProvider.isRemoteAttachment(entry);
    final isVideo = _isVideoPath(entry);

    Widget content;
    if (isVideo) {
      content = Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 28),
        ),
      );
    } else if (isRemote) {
      content = Image.network(
        _fullUrl(entry),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFF5F1EA),
          child: const Icon(Icons.broken_image, color: Colors.black26),
        ),
      );
    } else {
      content = Image.file(File(entry), fit: BoxFit.cover);
    }

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => _openAttachment(entry),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: content,
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Yuborishdan oldin: biriktirmalar ro'yxati + qo'shish tugmasi.
  Widget _buildAttachmentsEditor(YukProvider provider) {
    final entries = provider.attachmentsFor(order.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...entries.map(
            (e) => _attachmentTile(
              e,
              onRemove: () => provider.removeAttachment(order.id, e),
            ),
          ),
          // Qo'shish plitkasi.
          GestureDetector(
            onTap: _showAddAttachmentSheet,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentColor),
                color: _accentColor.withValues(alpha: 0.06),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: _accentColor, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Rasm/video',
                    style: TextStyle(fontSize: 9, color: _accentColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Yuborilgan buyurtmada: biriktirmalarni faqat ko'rish.
  Widget _buildAttachmentsViewer() {
    if (order.attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: order.attachments.map(_attachmentTile).toList(),
      ),
    );
  }

  // Inline kichik narx maydoni (jadval ustuni ichida).
  Widget _inlineField({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    String? hint,
    bool decimal = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType:
          TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        decimal
            ? DecimalInputFormatter()
            : ThousandsSeparatorInputFormatter(),
      ],
      onChanged: onChanged,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: enabled ? Colors.black87 : Colors.black54,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        isDense: true,
        filled: !enabled,
        fillColor: const Color(0xFFF5F1EA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentColor),
        ),
      ),
    );
  }

  // Jadval ustunlari uchun nisbatlar — sarlavha va qatorlar bir xil ishlatadi.
  static const int _nameFlex = 5;
  static const int _qtyFlex = 3;
  static const int _sumFlex = 3;

  @override
  Widget build(BuildContext context) {
    return Consumer<YukProvider>(
      builder: (context, provider, child) {
        final done = _isDone;
        final hasAnyPrice = provider.hasAnyPrice(order.id);
        // Yuborilgan buyurtmada jami backenddan keladi; aks holda lokal hisob.
        final orderTotal =
            done ? order.total.toDouble() : provider.orderTotal(order.id);
        final submitting = provider.submittingOrderId == order.id;
        final reverting = provider.revertingOrderId == order.id;
        // Yuborilgan buyurtmani qaytarib olishgacha qolgan soniyalar (0 = yo'q).
        final undoLeft =
            done ? provider.undoRemaining(order.id).inSeconds : 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: done
                ? Border.all(color: const Color(0xFF4CAF50), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(order.created),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.store_outlined,
                      size: 16, color: _accentColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.username,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Yuborilgan buyurtma uchun yashil belgi.
                  if (done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF4CAF50)),
                          SizedBox(width: 4),
                          Text(
                            'Yuborilgan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Divider(height: 18),
              // Jadval sarlavhasi (ustun nomlari).
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Expanded(
                      flex: _nameFlex,
                      child: Text(
                        'Mahsulot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      flex: _qtyFlex,
                      child: Text(
                        'Nechta olgani',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      flex: _sumFlex,
                      child: Text(
                        'Jami summa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Jadval qatorlari — har bir mahsulot uchun nom + ikkita maydon.
              // Pending'da faqat katalog itemlari (proche/rasxod lokal
              // ro'yxatdan alohida chiqadi); yuborilganда rasxoddan tashqari
              // hammasi (proche oddiy qator sifatida).
              ...order.items
                  .where((i) => done ? !i.isRasxod : i.itemType.isEmpty)
                  .map((item) {
                // Bittasining narxi = jami summa / olingan miqdor.
                // Lokal kiritma bo'lmasa, yuborilgan (backend) qiymatlardan olinadi.
                // Omborchi qabul qilgan itemda olingan miqdor QULFLANGAN —
                // birlik narx har doim shu (avto) qiymat bilan hisoblanadi:
                // faqat summa yozilsa ham "1 *" narx darhol chiqadi.
                final priced = provider.getItemPrice(order.id, item.productId);
                final takenVal =
                    _lockedTaken(item) ?? priced?.taken ?? item.taken;
                final subtotalVal = priced?.subtotal ?? item.subtotal;
                final unitPrice = (takenVal > 0 && subtotalVal > 0)
                    ? subtotalVal / takenVal
                    : null;
                // Olingan miqdor * birlik narxi: "5.250 * 9 524".
                final unitLabel = unitPrice != null
                    ? '${_fmtQty(takenVal)} * ${_formatMoney(unitPrice)}'
                    : '';
                // Buyurtma soniga nisbatan farq: ortiq olinsa +yashil,
                // kam olinsa -qizil. Masalan 3 so'ralib 5 olinsa "+2".
                final diff = takenVal - item.count;
                // Proche (qo'shilgan) mahsulotda buyurtma soni yo'q — farq
                // ko'rsatilmaydi.
                final showDiff =
                    !item.isProche && takenVal > 0 && diff.abs() > 0.0001;
                final diffText = diff > 0
                    ? '+${_fmtQty(diff)}'
                    : '-${_fmtQty(diff.abs())}';
                final diffColor = diff > 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828);
                // Omborchi qabul qilgan item: kelgan soni socket orqali
                // kelganda maydon avtomatik yangilanadi va QULFLANADI
                // (yuk keltiruvchi uni o'zgartira olmaydi, faqat narx kiritadi).
                if (item.accepted) {
                  final want =
                      _fmtQty(item.received > 0 ? item.received : item.taken);
                  final ctrl = _takenCtrlFor(item);
                  if (ctrl.text != want) ctrl.text = want;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: _nameFlex,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // Mahsulot nomi ustiga bosilsa klaviatura yopiladi.
                          onTap: () => FocusScope.of(context).unfocus(),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  item.isProche
                                      ? 'Qo\'shimcha'
                                      : '${_formatCount(item.count)}'
                                          '${item.type != null && item.type!.isNotEmpty ? ' ${item.type}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                // Buyurtmaga nisbatan ortiq/kam olingan farqi.
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
                            // Bittasining narxi (jami / miqdor) — kiritilganda.
                            if (unitPrice != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                unitLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: _qtyFlex,
                        child: _inlineField(
                          controller: _takenCtrlFor(item),
                          focusNode: _takenFocusFor(item),
                          hint: '0',
                          // kg mahsulot bo'lsa o'nlik (8.500) kiritsa bo'ladi.
                          decimal: _isKg(item.type),
                          // Omborchi qabul qilgan itemning kelgan soni
                          // qulflangan — faqat narx (summa) kiritiladi.
                          enabled: !done && !item.accepted,
                          onChanged: (_) => _onItemChanged(item),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: _sumFlex,
                        child: _inlineField(
                          controller: _subtotalCtrlFor(item),
                          hint: '0',
                          enabled: !done,
                          onChanged: (_) => _onItemChanged(item),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Qo'shilgan proche mahsulotlar (hali yuborilmagan, lokal).
              if (!done)
                ...provider
                    .addedItemsFor(order.id)
                    .asMap()
                    .entries
                    .where((e) => e.value.isProche)
                    .map((e) => _addedProcheRow(provider, e.key, e.value)),
              // Qo'shimcha mahsulot / xarajat qo'shish tugmalari.
              if (!done)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddEntrySheet(rasxod: false),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Mahsulot qo\'shish',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accentColor,
                            side: const BorderSide(color: _accentColor),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddEntrySheet(rasxod: true),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Xarajat qo\'shish',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8D6E63),
                            side: const BorderSide(color: Color(0xFF8D6E63)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Xarajatlar (rasxod) bloki — Jami'dan oldin.
              _buildRasxodBlock(provider),
              const Divider(height: 18),
              // Chek yakuni: Mahsulot / Xarajat (bo'lsa) / Jami.
              Builder(
                builder: (_) {
                  // Ombor kam qabul qilgan bo'lsa (received_total != total),
                  // mahsulot summasi qizil+chizilgan, yangisi yashilda.
                  final expenses = done
                      ? order.expensesTotal
                      : provider.addedExpensesTotal(order.id);
                  final received = order.receivedTotal;
                  final reduced = done &&
                      received > 0 &&
                      (received - order.total).abs() > 0.0001;
                  final effectiveMahsulot = reduced ? received : orderTotal;
                  final grandTotal = effectiveMahsulot + expenses;

                  Widget mahsulotValue;
                  if (!reduced) {
                    mahsulotValue = Text(
                      '${_formatMoney(orderTotal)} so\'m',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    );
                  } else {
                    mahsulotValue = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_formatMoney(order.total)} so\'m',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC62828),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFFC62828),
                            decorationThickness: 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatMoney(received)} so\'m',
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
                              '${_formatMoney(expenses)} so\'m',
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
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${_formatMoney(grandTotal)} so\'m',
                            style: const TextStyle(
                              fontSize: 15,
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
              const SizedBox(height: 10),
              // Yuborish tugmasi tepasida rasm/video biriktirish joyi:
              // kamera yoki galereyadan, bir nechta bo'lishi mumkin.
              if (!done)
                _buildAttachmentsEditor(provider)
              else
                _buildAttachmentsViewer(),
              // Yuborilgan buyurtmada tugma o'rniga "Yuborilgan" belgisi va
              // (30 soniya ichida) "Qaytarib olish" tugmasi.
              if (done)
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 18, color: Color(0xFF2E7D32)),
                          SizedBox(width: 6),
                          Text(
                            'Yuborilgan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (undoLeft > 0) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: reverting
                              ? null
                              : () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final ok =
                                      await provider.revertOrder(order.id);
                                  if (ok) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Qaytarib olindi'),
                                      ),
                                    );
                                  } else if (provider.errorMessage != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(provider.errorMessage!),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: reverting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFC62828),
                                  ),
                                )
                              : const Icon(Icons.undo, size: 18),
                          label: Text(
                            reverting
                                ? 'Qaytarilmoqda...'
                                : 'Qaytarib olish ($undoLeft s)',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            side: const BorderSide(color: Color(0xFFC62828)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (!hasAnyPrice || submitting)
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await provider.submitPrices(order.id);
                            if (ok) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Yuborildi'),
                                ),
                              );
                            } else if (provider.errorMessage != null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(provider.errorMessage!),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(submitting ? 'Yuborilmoqda...' : 'Yuborish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
