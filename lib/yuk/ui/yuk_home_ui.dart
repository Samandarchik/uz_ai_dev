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
import 'package:uz_ai_dev/yuk/models/yuk_transfer_model.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_history_ui.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_profile_ui.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_transfer_history_ui.dart';

// Sklad nomlari (loyihaning boshqa joylarida ham shu hardcode map ishlatiladi).
const Map<int, String> kSkladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
  4: 'Personal Sklad',
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
      // Targovli tizimidan kelgan (qabul kutayotgan) pullar.
      await provider.fetchTransfers();
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
                // Targovli tizimidan kelgan, qabul kutayotgan pullar —
                // barcha sklad tablarining tepasida ko'rinadi.
                for (final t in provider.transfers)
                  _TransferCard(
                    key: ValueKey('transfer_${t.id}'),
                    transfer: t,
                  ),
                Expanded(
                  child: TabBarView(
                    children: _sklads.map((id) {
                      // Asosiy sahifada faqat hali yuborilmagan buyurtmalar
                      // (yuborilganlar AppBar'dagi tarix ekranida).
                      final orders = provider.pendingForSklad(id);
                      return RefreshIndicator(
                        onRefresh: () async {
                          await provider.fetchOrders();
                          await provider.fetchTransfers();
                        },
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
                            : ListView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                children: [
                                  // Skladning HAMMA yuborilmagan buyurtmalari
                                  // bitta jamlangan kunlik ro'yxat (buyurtma
                                  // IDlarisiz), pastda bitta "Yuborish".
                                  YukSkladCard(
                                    key: ValueKey('sklad_$id'),
                                    skladId: id,
                                    orders: orders,
                                  ),
                                ],
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
        // Targovli'dan kelgan pullar tarixi (qabul qilingan/rad etilgan/
        // kutilayotgan — jami summalar bilan).
        IconButton(
          onPressed: () => context.push(const YukTransferHistoryUi()),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          tooltip: 'Pullar tarixi',
        ),
        // Yuborilgan buyurtmalar tarixi.
        IconButton(
          onPressed: () => context.push(YukHistoryUi(sklads: _sklads)),
          icon: const Icon(Icons.history),
          tooltip: 'Yuborilganlar tarixi',
        ),
        IconButton(
          onPressed: () => context.push(const YukProfileUi()),
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

// Targovli tizimidan kelgan, qabul kutayotgan bitta pul kartasi.
// «Qabul qilish» — summa kunlik hisob daftariga (Prixod) tushadi va targovli
// tomonga "qabul qilindi" qaytariladi. «Rad etish» — sabab yoziladi (majburiy),
// kassir uni ko'rib qayta yuborishi mumkin.
class _TransferCard extends StatelessWidget {
  final YukTransfer transfer;
  const _TransferCard({super.key, required this.transfer});

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rad etish'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: 'Sabab (majburiy)',
            hintText: 'Nima uchun rad etyapsiz?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rad etish',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rad etish uchun sabab yozing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await _decide(context, accept: false, reason: reason);
  }

  Future<void> _decide(
    BuildContext context, {
    required bool accept,
    String reason = '',
  }) async {
    final provider = context.read<YukProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.decideTransfer(
        transfer.id,
        accept: accept,
        reason: reason,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Pul qabul qilindi ✓ (hisobingizga tushdi)'
              : 'Pul rad etildi'),
          backgroundColor: accept ? Colors.green.shade700 : Colors.orange,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deciding =
        context.watch<YukProvider>().decidingTransferId == transfer.id;
    final dateStr = transfer.created == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(transfer.created!.toLocal());
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: const Color(0xFFFFFDE7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: Colors.amber.shade800),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Sizga pul yuborildi (Targovli)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatMoney(transfer.amount)} so\'m',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (transfer.senderName.isNotEmpty)
              Text(
                'Yubordi: ${transfer.senderName}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            if (transfer.comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  transfer.comment,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: deciding
                        ? null
                        : () => _decide(context, accept: true),
                    icon: deciding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Qabul qilish'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    onPressed: deciding ? null : () => _reject(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rad etish'),
                  ),
                ),
              ],
            ),
          ],
        ),
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

// ═══════════ Sklad bo'yicha JAMLANGAN kunlik ro'yxat (achot) ═══════════
// Asosiy sahifada buyurtma IDlari ko'rsatilmaydi: skladning hamma
// yuborilmagan buyurtmalari bitta ro'yxat bo'lib chiqadi. Bir sklad 2 marta
// buyurtma bersa itemlari ALOHIDA qator bo'lib qo'shiladi (jamlanmaydi) —
// orasida kichik vaqt chizig'i turadi. Yuk kun davomida miqdor/summa yozib
// boradi, kechqurun BITTA "Yuborish" bilan hammasi yopiladi (achot yopiladi).
// Ichkarida har buyurtma backendda alohida saqlanadi — ombor qabuli, kamomad
// va ledger hisoblari o'zgarmaydi.
class YukSkladCard extends StatefulWidget {
  final int skladId;
  final List<YukOrder> orders;
  const YukSkladCard({
    super.key,
    required this.skladId,
    required this.orders,
  });

  @override
  State<YukSkladCard> createState() => _YukSkladCardState();
}

class _YukSkladCardState extends State<YukSkladCard> {
  static const Color _accentColor = Color(0xFFC5A97B);

  // Jadval ustunlari uchun nisbatlar — sarlavha va qatorlar bir xil ishlatadi.
  static const int _nameFlex = 5;
  static const int _qtyFlex = 3;
  static const int _sumFlex = 3;

  // Controllerlar buyurtma+mahsulot juftligi bo'yicha ('<orderId>_<productId>')
  // — bir xil mahsulot ikki buyurtmada kelsa qatorlar aralashmaydi.
  final Map<String, TextEditingController> _takenControllers = {};
  final Map<String, TextEditingController> _subtotalControllers = {};
  final Map<String, FocusNode> _takenFocusNodes = {};
  // Summa maydoni fokusda turganda socketdan kelgan qiymat uni bosib
  // qo'ymasligi uchun summaga ham FocusNode kerak.
  final Map<String, FocusNode> _subtotalFocusNodes = {};

  // Boshlang'ich qiymatlari tayyorlangan buyurtmalar (socket orqali yangi
  // buyurtma kelsa didUpdateWidget'da faqat yangilari init bo'ladi).
  final Set<int> _initedOrders = {};

  final ImagePicker _picker = ImagePicker();
  Timer? _undoTicker;

  String _key(int orderId, int productId) => '${orderId}_$productId';

  static bool _isDoneOrder(YukOrder o) =>
      o.status == 'narxlandi' || o.status == 'qabul_qilindi';

  // Buyurtmalar sana bo'yicha o'sish tartibida (birinchi kelgani tepada).
  List<YukOrder> get _sorted {
    final list = List<YukOrder>.of(widget.orders);
    list.sort((a, b) {
      final da = DateTime.tryParse(a.created) ?? DateTime(2000);
      final db = DateTime.tryParse(b.created) ?? DateTime(2000);
      return da.compareTo(db);
    });
    return list;
  }

  // Yangi qo'shimcha yozuv (proche/rasxod) va rasm/video biriktiriladigan
  // buyurtma — eng birinchi yuborilmagan buyurtma (kun davomida barqaror).
  YukOrder? get _anchor {
    for (final o in _sorted) {
      if (!_isDoneOrder(o)) return o;
    }
    return null;
  }

  String _fmt(double v) {
    if (v == 0) return '';
    return _formatMoney(v);
  }

  String _fmtQty(double v) {
    if (v == 0) return '';
    var s = v.toStringAsFixed(3);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  bool _isKg(String? type) {
    if (type == null) return false;
    final t = type.toLowerCase();
    return t.contains('kg') || t.contains('кг');
  }

  double _parse(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null || v < 0) return 0;
    return v;
  }

  String _formatCount(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd.MM HH:mm').format(dt.toLocal());
  }

  static bool _isVideoPath(String p) {
    final ext = p.split('.').last.toLowerCase();
    return const {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'}
        .contains(ext);
  }

  static String _fullUrl(String url) =>
      url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';

  @override
  void initState() {
    super.initState();
    for (final o in widget.orders) {
      _initOrder(o);
    }
    _maybeStartUndoTicker();
  }

  // Bitta buyurtma itemlari uchun controllerlarni yaratish va boshlang'ich
  // qiymatlarni tiklash (YukOrderCard.initState'dagi mantiq bilan bir xil).
  void _initOrder(YukOrder order) {
    if (!_initedOrders.add(order.id)) return;
    final provider = context.read<YukProvider>();
    final done = _isDoneOrder(order);
    for (final item in order.items) {
      final k = _key(order.id, item.productId);
      // Avval shu sessiyada kiritilgan qiymat, bo'lmasa backenddan kelgan
      // qiymat. Omborchi qabul qilgan itemda lokal qoralama bo'sh bo'lsa,
      // omborchi kiritgan kelgan soni bilan to'ldiriladi (maydon qulf).
      final existing = provider.getItemPrice(order.id, item.productId);
      final draftTaken = existing?.taken;
      final taken0 = (draftTaken != null && draftTaken > 0)
          ? draftTaken
          : (item.accepted && item.received > 0
              ? item.received
              : item.taken);
      final subtotal0 = existing?.subtotal ?? item.subtotal;
      _takenControllers[k] = TextEditingController(text: _fmtQty(taken0));
      _subtotalControllers[k] = TextEditingController(text: _fmt(subtotal0));
      _takenFocusNodes[k] = FocusNode();
      _subtotalFocusNodes[k] = FocusNode();
      // Qaytarib olingan (pending bo'lib qolgan) buyurtmada oldingi qiymatlar
      // qayta yuborilishi uchun lokal narxga tiklab qo'yamiz. BOSHQA yuk
      // keltiruvchi boshlagan qoralama (priced_by boshqa) seed QILINMAYDI —
      // aks holda flushDrafts uni bizning nomimizdan qayta yuborib, hisoblar
      // aralashib ketadi.
      if (!done &&
          provider.canSeedOrder(order) &&
          existing == null &&
          item.itemType.isEmpty &&
          (taken0 > 0 || subtotal0 > 0)) {
        provider.seedItemPrice(order.id, item.productId, taken0, subtotal0);
      }
    }
    // Qaytarib olingan buyurtmaning serverda qolgan biriktirma va
    // proche/rasxod itemlarini lokal ro'yxatlarga tiklaymiz.
    if (!done && provider.canSeedOrder(order)) {
      if (order.attachments.isNotEmpty) {
        provider.seedAttachments(order.id, order.attachments);
      }
      provider.seedAddedItems(order.id, order.items);
    }
  }

  // Ombor biror itemni qabul qilganda (socket orqali keladi) uning kelgan
  // soni "Nechta olgani" maydoniga AVTO to'ldiriladi va maydon QULFLANADI.
  // Shuningdek boshqa qurilma/yuk keltiruvchi yozgan miqdor-summalar ham
  // socketdan kelib maydonlarga JONLI tushiriladi ("Yuborish"siz).
  @override
  void didUpdateWidget(covariant YukSkladCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final provider = context.read<YukProvider>();
    final oldItems = <String, YukOrderItem>{
      for (final o in oldWidget.orders)
        for (final i in o.items) _key(o.id, i.productId): i,
    };
    // didUpdateWidget build fazasida ishlaydi — provider'ga yozish
    // (notifyListeners) shu yerda chaqirilsa "setState during build" xatosi
    // chiqadi; shuning uchun yozuvlar keyingi freymga qoldiriladi.
    final deferred = <void Function()>[];
    for (final o in widget.orders) {
      // Kun davomida yangi kelgan buyurtma — controllerlarini hozir yaratamiz.
      _initOrder(o);
      final done = _isDoneOrder(o);
      for (final item in o.items) {
        final k = _key(o.id, item.productId);
        final old = oldItems[k];
        if (item.accepted && !(old?.accepted ?? false)) {
          final v = item.received > 0 ? item.received : item.taken;
          _takenCtrlFor(o, item).text = _fmtQty(v);
          deferred.add(() => _onItemChanged(o, item));
          continue;
        }
        // ─── REAL-TIME sinxronlash ───
        // Qiymat o'zgarmagan, buyurtma yopiq/qabul qilingan yoki item endi
        // paydo bo'lgan bo'lsa tegmaymiz.
        if (done || item.accepted || old == null) continue;
        if (old.taken == item.taken && old.subtotal == item.subtotal) {
          continue;
        }
        // O'zimning hali serverga yetib bormagan (debounce kutayotgan)
        // qoralamam bor — socketdagi eski qiymat uni bosib qo'ymasin.
        if (provider.draftSaveScheduled(o.id)) continue;
        final takenFocused = _takenFocusNodes[k]?.hasFocus ?? false;
        final sumFocused = _subtotalFocusNodes[k]?.hasFocus ?? false;
        if (old.taken != item.taken && !takenFocused) {
          final ctrl = _takenCtrlFor(o, item);
          if (_parse(ctrl.text) != item.taken) {
            ctrl.text = _fmtQty(item.taken);
          }
        }
        if (old.subtotal != item.subtotal && !sumFocused) {
          final ctrl = _subtotalCtrlFor(o, item);
          if (_parse(ctrl.text) != item.subtotal) {
            ctrl.text = _fmt(item.subtotal);
          }
        }
        // O'z buyurtmamda (masalan ikkinchi qurilmam yozgan) lokal narxni
        // ham sinxronlaymiz — flush baribir no-op (server bilan teng).
        if (provider.canSeedOrder(o) && !takenFocused && !sumFocused) {
          provider.seedItemPrice(
              o.id, item.productId, item.taken, item.subtotal);
        }
      }
    }
    if (deferred.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final apply in deferred) {
          apply();
        }
      });
    }
    _maybeStartUndoTicker();
  }

  // Achot endigina yopilgan bo'lsa "Qaytarib olish" sanog'ini har soniyada
  // yangilab turamiz; muddat tugashi bilan timer to'xtaydi.
  void _maybeStartUndoTicker() {
    final provider = context.read<YukProvider>();
    if (provider.undoRemainingForSklad(widget.skladId) == Duration.zero) {
      return;
    }
    _undoTicker?.cancel();
    _undoTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {});
      if (context.read<YukProvider>().undoRemainingForSklad(widget.skladId) ==
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
    for (final f in _subtotalFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // Controllerlarni kerak bo'lganda yaratish (masalan buyurtma yuborilgach
  // serverdan yangi proche/rasxod itemlar kelsa) — null crash bo'lmasin.
  TextEditingController _takenCtrlFor(YukOrder order, YukOrderItem item) =>
      _takenControllers.putIfAbsent(
        _key(order.id, item.productId),
        () => TextEditingController(text: _fmtQty(item.taken)),
      );

  TextEditingController _subtotalCtrlFor(YukOrder order, YukOrderItem item) =>
      _subtotalControllers.putIfAbsent(
        _key(order.id, item.productId),
        () => TextEditingController(text: _fmt(item.subtotal)),
      );

  FocusNode _takenFocusFor(YukOrder order, YukOrderItem item) =>
      _takenFocusNodes.putIfAbsent(
          _key(order.id, item.productId), () => FocusNode());

  FocusNode _subtotalFocusFor(YukOrder order, YukOrderItem item) =>
      _subtotalFocusNodes.putIfAbsent(
          _key(order.id, item.productId), () => FocusNode());

  void _onItemChanged(YukOrder order, YukOrderItem item) {
    final provider = context.read<YukProvider>();
    final k = _key(order.id, item.productId);
    final taken = _parse(_takenControllers[k]?.text ?? '');
    final subtotal = _parse(_subtotalControllers[k]?.text ?? '');
    provider.setItemPrice(order.id, item.productId, taken, subtotal);
  }

  // ─────────────────── Biriktirmalar (rasm/video) ───────────────────

  Future<void> _pickFromCamera(int orderId, {required bool video}) async {
    try {
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.camera);
      if (file == null || !mounted) return;
      context.read<YukProvider>().addAttachments(orderId, [file.path]);
    } catch (_) {
      // Ruxsat berilmagan/bekor qilingan — jim.
    }
  }

  Future<void> _pickFromGallery(int orderId) async {
    try {
      final List<XFile> files = await _picker.pickMultipleMedia();
      if (files.isEmpty || !mounted) return;
      context
          .read<YukProvider>()
          .addAttachments(orderId, files.map((f) => f.path).toList());
    } catch (_) {
      // Ruxsat berilmagan/bekor qilingan — jim.
    }
  }

  void _showAddAttachmentSheet(int orderId) {
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
                _pickFromCamera(orderId, video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: _accentColor),
              title: const Text('Kamera — video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromCamera(orderId, video: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _accentColor),
              title: const Text('Galereya (rasm/video)'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery(orderId);
              },
            ),
          ],
        ),
      ),
    );
  }

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
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(String entry, {VoidCallback? onRemove}) {
    final isRemote = YukProvider.isRemoteAttachment(entry);
    final isVideo = _isVideoPath(entry);

    Widget content;
    if (isVideo) {
      content = Container(
        color: Colors.black87,
        child: const Center(
          child:
              Icon(Icons.play_circle_outline, color: Colors.white, size: 28),
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

  // Yuborishdan oldin: hamma ochiq buyurtmalarning biriktirmalari + qo'shish
  // tugmasi (yangi rasm/video anchor buyurtmaga biriktiriladi).
  Widget _buildAttachmentsEditor(
    YukProvider provider,
    List<YukOrder> pending,
    YukOrder? anchor,
  ) {
    final tiles = <Widget>[];
    for (final o in pending) {
      for (final e in provider.attachmentsFor(o.id)) {
        tiles.add(_attachmentTile(
          e,
          onRemove: () => provider.removeAttachment(o.id, e),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...tiles,
          if (anchor != null)
            GestureDetector(
              onTap: () => _showAddAttachmentSheet(anchor.id),
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

  // Yopilgan achotda: biriktirmalarni faqat ko'rish.
  Widget _buildAttachmentsViewer(List<YukOrder> orders) {
    final entries = <String>[
      for (final o in orders) ...o.attachments,
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map(_attachmentTile).toList(),
      ),
    );
  }

  // ─────────── Qo'shimcha yozuv (proche mahsulot / rasxod) qo'shish ───────────

  void _showAddEntrySheet(int orderId, {required bool rasxod}) {
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
                        orderId,
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

  Widget _addedProcheRow(
    YukProvider provider,
    int orderId,
    int index,
    YukAddedItem item,
  ) {
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
                  onTap: () => provider.removeAddedItem(orderId, index),
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

  // Begona buyurtmaning serverdagi proche itemi — o'chirib bo'lmaydigan qator
  // (kim boshlagan bo'lsa o'sha o'chiradi; bizda faqat ko'rinadi).
  Widget _remoteProcheRow(YukOrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: _nameFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
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

  // "Xarajatlar" bloki: HAMMA buyurtmalarning rasxod yozuvlari birga.
  // Begona (boshqa yuk user boshlagan) ochiq buyurtmaning rasxodlari
  // serverdagi itemlardan READ-ONLY ko'rsatiladi (real-time socketdan tushadi).
  Widget _buildRasxodBlock(YukProvider provider, List<YukOrder> orders) {
    final rows = <Widget>[];
    for (final order in orders) {
      if (_isDoneOrder(order)) {
        for (final item in order.items.where((i) => i.isRasxod)) {
          rows.add(_rasxodRow(item.name, item.subtotal));
        }
      } else if (!provider.canSeedOrder(order)) {
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
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
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

  // Ikki buyurtma orasidagi yupqa vaqt chizig'i (ID ko'rsatilmaydi —
  // faqat qachon va kim yuborgani).
  Widget _batchLabel(YukOrder order) {
    final label = [
      _formatTime(order.created),
      if (order.username.isNotEmpty) order.username,
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // Bitta katalog/proche item qatori (YukOrderCard'dagi bilan bir xil ko'rinish,
  // faqat controllerlar buyurtma+mahsulot bo'yicha).
  Widget _itemRow(YukProvider provider, YukOrder order, YukOrderItem item) {
    final done = _isDoneOrder(order);
    final priced = provider.getItemPrice(order.id, item.productId);
    final takenCtrl = _takenControllers[_key(order.id, item.productId)];
    final takenVal = (!done && takenCtrl != null)
        ? _parse(takenCtrl.text)
        : (priced?.taken ?? item.taken);
    final subtotalVal = priced?.subtotal ?? item.subtotal;
    final unitPrice =
        (takenVal > 0 && subtotalVal > 0) ? subtotalVal / takenVal : null;
    final unitLabel = unitPrice != null
        ? '${_fmtQty(takenVal)} * ${_formatMoney(unitPrice)}'
        : '';
    final diff = takenVal - item.count;
    final showDiff =
        !item.isProche && takenVal > 0 && diff.abs() > 0.0001;
    final diffText =
        diff > 0 ? '+${_fmtQty(diff)}' : '-${_fmtQty(diff.abs())}';
    final diffColor =
        diff > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: _nameFlex,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
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
              controller: _takenCtrlFor(order, item),
              focusNode: _takenFocusFor(order, item),
              hint: '0',
              decimal: _isKg(item.type),
              // Ombor qabul qilgan itemning soni QULFLANADI.
              enabled: !done && !item.accepted,
              onChanged: (_) => _onItemChanged(order, item),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _sumFlex,
            child: _inlineField(
              controller: _subtotalCtrlFor(order, item),
              focusNode: _subtotalFocusFor(order, item),
              hint: '0',
              enabled: !done,
              onChanged: (_) => _onItemChanged(order, item),
            ),
          ),
        ],
      ),
    );
  }

  // Yuborishdan oldin tasdiq: hech narsa kiritilmagan qatorlar bo'lsa
  // ogohlantiramiz — ular "olinmagan" deb yopiladi.
  Future<void> _confirmAndSubmit(
    YukProvider provider,
    List<YukOrder> pending,
  ) async {
    var unfilled = 0;
    for (final o in pending) {
      for (final item in o.items.where((i) => i.itemType.isEmpty)) {
        final k = _key(o.id, item.productId);
        final taken = _parse(_takenControllers[k]?.text ?? '');
        final subtotal = _parse(_subtotalControllers[k]?.text ?? '');
        if (taken <= 0 && subtotal <= 0) unfilled++;
      }
    }
    if (unfilled > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Achotni yopish'),
          content: Text(
            '$unfilled ta mahsulotga hech narsa kiritilmagan — ular '
            '«olinmagan» deb yopiladi. Yuborilsinmi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yuborish'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.submitAllForSklad(widget.skladId);
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Yuborildi — achot yopildi')),
      );
    } else if (provider.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
    _maybeStartUndoTicker();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<YukProvider>(
      builder: (context, provider, child) {
        final orders = _sorted;
        final pending =
            orders.where((o) => !_isDoneOrder(o)).toList();
        final allDone = orders.isNotEmpty && pending.isEmpty;
        final anchor = _anchor;
        final submitting = provider.submittingSkladId == widget.skladId;
        final reverting = provider.revertingSkladId == widget.skladId;
        final hasAnyPrice = provider.hasAnyPriceForSklad(widget.skladId);
        final undoLeft = allDone
            ? provider.undoRemainingForSklad(widget.skladId).inSeconds
            : 0;

        // Jami summalar: yuborilganlari backenddan; ochiqlari — lokal
        // kiritilgan qiymat, bo'lmasa serverdagi (boshqa qurilma/yuk user
        // yozgani socketdan tushadi) qiymat. Begona (boshqa user boshlagan)
        // buyurtmaning proche/rasxodi serverdagi itemlardan olinadi.
        var mahsulot = 0.0;
        var xarajat = 0.0;
        for (final o in orders) {
          if (_isDoneOrder(o)) {
            mahsulot += o.total.toDouble();
            xarajat += o.expensesTotal;
            continue;
          }
          final mine = provider.canSeedOrder(o);
          for (final item in o.items) {
            if (item.itemType.isEmpty) {
              mahsulot +=
                  provider.getItemPrice(o.id, item.productId)?.subtotal ??
                      item.subtotal;
            } else if (!mine) {
              if (item.isRasxod) {
                xarajat += item.subtotal;
              } else {
                mahsulot += item.subtotal;
              }
            }
          }
          if (mine) {
            mahsulot += provider.addedProductsTotal(o.id);
            xarajat += provider.addedExpensesTotal(o.id);
          }
        }
        final grandTotal = mahsulot + xarajat;

        // Bitta buyurtma bo'lsa vaqt chizig'i shart emas; ikki va undan ko'p
        // bo'lsa har guruh alohida ko'rinadi (itemlar JAMLANMAYDI).
        final showBatchLabels = orders.length > 1;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: allDone
                ? Border.all(color: const Color(0xFF4CAF50), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              // Har buyurtma itemlari alohida qator bo'lib ketma-ket chiqadi.
              for (final order in orders) ...[
                if (showBatchLabels) _batchLabel(order),
                ...order.items
                    .where((i) => _isDoneOrder(order)
                        ? !i.isRasxod
                        : i.itemType.isEmpty)
                    .map((item) => _itemRow(provider, order, item)),
                // Begona (boshqa yuk user boshlagan) ochiq buyurtmaning
                // serverdagi proche itemlari — read-only, real-time.
                if (!_isDoneOrder(order) && !provider.canSeedOrder(order))
                  ...order.items
                      .where((i) => i.isProche)
                      .map(_remoteProcheRow),
                if (!_isDoneOrder(order))
                  ...provider
                      .addedItemsFor(order.id)
                      .asMap()
                      .entries
                      .where((e) => e.value.isProche)
                      .map((e) => _addedProcheRow(
                          provider, order.id, e.key, e.value)),
              ],
              // Qo'shimcha mahsulot / xarajat qo'shish tugmalari.
              if (anchor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showAddEntrySheet(anchor.id, rasxod: false),
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
                          onPressed: () =>
                              _showAddEntrySheet(anchor.id, rasxod: true),
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
              _buildRasxodBlock(provider, orders),
              const Divider(height: 18),
              // Achot yakuni: Mahsulot / Xarajat (bo'lsa) / Jami.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mahsulot:',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  Text(
                    '${_formatMoney(mahsulot)} so\'m',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (xarajat > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Xarajat:',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Text(
                      '${_formatMoney(xarajat)} so\'m',
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
                    style: TextStyle(fontSize: 14, color: Colors.black54),
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
              const SizedBox(height: 10),
              // Yuborish tugmasi tepasida rasm/video biriktirish joyi.
              if (!allDone)
                _buildAttachmentsEditor(provider, pending, anchor)
              else
                _buildAttachmentsViewer(orders),
              // Achot yopilgan bo'lsa "Yuborilgan" belgisi va (30 soniya
              // ichida) "Qaytarib olish"; aks holda bitta "Yuborish".
              if (allDone)
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF4CAF50).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 18, color: Color(0xFF2E7D32)),
                          SizedBox(width: 6),
                          Text(
                            'Yuborilgan — achot yopildi',
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
                                  final ok = await provider
                                      .revertAllForSklad(widget.skladId);
                                  if (ok) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Qaytarib olindi'),
                                      ),
                                    );
                                  } else if (provider.errorMessage != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content:
                                            Text(provider.errorMessage!),
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
                            side:
                                const BorderSide(color: Color(0xFFC62828)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
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
                        : () => _confirmAndSubmit(provider, pending),
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
      // (yuborilgan) qiymat ko'rsatiladi. Omborchi qabul qilgan itemda lokal
      // qoralama bo'sh (0) bo'lsa, omborchi kiritgan kelgan soni bilan
      // to'ldiriladi (maydon qulf — qabul qilingan son yakuniy).
      final existing = provider.getItemPrice(order.id, item.productId);
      final draftTaken = existing?.taken;
      final taken0 = (draftTaken != null && draftTaken > 0)
          ? draftTaken
          : (item.accepted && item.received > 0
              ? item.received
              : item.taken);
      final subtotal0 = existing?.subtotal ?? item.subtotal;
      _takenControllers[item.productId] =
          TextEditingController(text: _fmtQty(taken0));
      _subtotalControllers[item.productId] =
          TextEditingController(text: _fmt(subtotal0));
      _takenFocusNodes[item.productId] = FocusNode();
      // Qaytarib olingan (pending bo'lib qolgan) buyurtmada oldingi qiymatlar
      // qayta yuborilishi uchun lokal narxga tiklab qo'yamiz.
      // proche/rasxod itemlar bunga kirmaydi — ular added_items orqali ketadi.
      // BOSHQA yuk keltiruvchi boshlagan qoralama seed QILINMAYDI (flushDrafts
      // uni bizning nomimizdan qayta yubormasin — hisoblar aralashmasin).
      if (!_isDone &&
          provider.canSeedOrder(order) &&
          existing == null &&
          item.itemType.isEmpty &&
          (taken0 > 0 || subtotal0 > 0)) {
        provider.seedItemPrice(order.id, item.productId, taken0, subtotal0);
      }
    }
    // Qaytarib olingan buyurtmaning serverda qolgan biriktirma va
    // proche/rasxod itemlarini lokal ro'yxatlarga tiklaymiz (qayta
    // yuborishda yo'qolmasligi uchun; faqat o'zimizniki bo'lsa).
    if (!_isDone && provider.canSeedOrder(order)) {
      if (order.attachments.isNotEmpty) {
        provider.seedAttachments(order.id, order.attachments);
      }
      provider.seedAddedItems(order.id, order.items);
    }
    _maybeStartUndoTicker();
  }

  // Ombor biror itemni qabul qilganda (socket orqali keladi) uning kelgan
  // soni "Nechta olgani" maydoniga AVTO to'ldiriladi va maydon QULFLANADI —
  // qabul qilingan son yakuniy, yuk keltiruvchi uni o'zgartira olmaydi.
  @override
  void didUpdateWidget(covariant YukOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAccepted = {
      for (final i in oldWidget.order.items) i.productId: i.accepted,
    };
    // Provider yozuvlari (notifyListeners) build fazasida chaqirilmasligi
    // uchun keyingi freymga qoldiriladi ("setState during build" xatosi).
    final deferred = <void Function()>[];
    for (final item in order.items) {
      if (item.accepted && !(oldAccepted[item.productId] ?? false)) {
        final v = item.received > 0 ? item.received : item.taken;
        _takenCtrlFor(item).text = _fmtQty(v);
        // Providerga ham yozamiz — "1 *" birlik narx qayta hisoblanadi.
        deferred.add(() => _onItemChanged(item));
      }
    }
    if (deferred.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final apply in deferred) {
          apply();
        }
      });
    }
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

  void _onItemChanged(YukOrderItem item) {
    final provider = context.read<YukProvider>();
    final productId = item.productId;
    // Qiymat maydonning o'zidan (controller) olinadi. Qabul qilingan itemda
    // maydon qulf — controller'da omborchi tasdiqlagan son turadi (backend
    // ham accepted itemning taken'ini o'zgartirmaydi).
    final taken = _parse(_takenControllers[productId]?.text ?? '');
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
                // Tahrirlanadigan qatorda qiymat maydonning O'ZIDAN olinadi —
                // ekranda nima tursa, "1 *" narx shu bilan hisoblanadi
                // (avto to'lgan kelgan soni + faqat summa yozilsa ham chiqadi).
                final priced = provider.getItemPrice(order.id, item.productId);
                final takenCtrl = _takenControllers[item.productId];
                final takenVal = (!done && takenCtrl != null)
                    ? _parse(takenCtrl.text)
                    : (priced?.taken ?? item.taken);
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
                          // Ombor qabul qilgan itemning soni QULFLANADI —
                          // omborchi tasdiqlagan kelgan soni yakuniy.
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
