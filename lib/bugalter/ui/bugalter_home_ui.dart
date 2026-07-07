import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uz_ai_dev/bugalter/models/yuk_user_model.dart';
import 'package:uz_ai_dev/bugalter/provider/bugalter_provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_home_ui.dart'
    show ThousandsSeparatorInputFormatter;

// Sklad nomlari (yuk_home_ui dagi kSkladNames bilan bir xil).
const Map<int, String> _skladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
  4: 'Personal Sklad',
};

// Bugalter (hisobchi) roli uchun bosh ekran.
// Barcha skladlarning narxlangan/qabul qilingan buyurtmalari — mahsulotlar va
// xarajatlar (rasxod) bilan. "Hammasi" + har sklad uchun alohida tab.
class BugalterHomeUi extends StatefulWidget {
  const BugalterHomeUi({super.key});

  @override
  State<BugalterHomeUi> createState() => _BugalterHomeUiState();
}

class _BugalterHomeUiState extends State<BugalterHomeUi> {
  final TokenStorage tokenStorage = sl<TokenStorage>();

  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  // Tablar: null -> "Hammasi", keyin skladlar.
  static final List<int?> _tabs = [null, ..._skladNames.keys];

  // AppBar'dagi tugma bilan yoqiladi: buyurtmaga biriktirilgan
  // rasm/videolarni kartada ko'rsatish.
  bool _showImages = false;

  // Yuk keltiruvchi bo'yicha filtr (null -> hammasi). Buyurtma priced_by
  // maydoni bilan solishtiriladi.
  int? _selectedYukUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BugalterProvider>().fetchOrders();
      // Tepadagi filtr chiplari uchun yuk keltiruvchilar ro'yxati.
      context.read<BugalterProvider>().fetchYukUsers();
    });
  }

  void _logout() {
    tokenStorage.removeToken();
    tokenStorage.removeRefreshToken();
    context.push(LoginPage());
  }

  // "Pul berish" bottom sheet'ini ochish (yuk keltiruvchiga to'lov).
  void _openPaymentSheet() {
    // Dropdown uchun yuk keltiruvchilar ro'yxatini yangilab olamiz.
    context.read<BugalterProvider>().fetchYukUsers();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => const _PaymentSheet(),
    );
  }

  String _tabName(int? id) =>
      id == null ? 'Hammasi' : (_skladNames[id] ?? 'Sklad $id');

  // Sklad tablari tepasidagi yuk keltiruvchi filtri: "Hammasi" + har bir
  // yuk keltiruvchi nomi. Tanlanganda buyurtmalar priced_by bo'yicha
  // filtrlanadi.
  Widget _buildYukUserChips() {
    return Consumer<BugalterProvider>(
      builder: (context, provider, _) {
        if (provider.yukUsers.isEmpty) return const SizedBox(height: 44);
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final entry in <int?, String>{
                null: 'Hammasi',
                for (final u in provider.yukUsers) u.id: u.name,
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _selectedYukUserId == entry.key,
                    onSelected: (_) =>
                        setState(() => _selectedYukUserId = entry.key),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selectedYukUserId == entry.key
                          ? Colors.white
                          : Colors.black54,
                    ),
                    selectedColor: _accentColor,
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: _selectedYukUserId == entry.key
                          ? _accentColor
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Bugalter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: _showImages
                  ? 'Rasmlarni yashirish'
                  : 'Rasmlarni ko\'rsatish',
              onPressed: () => setState(() => _showImages = !_showImages),
              icon: Icon(
                _showImages ? Icons.image : Icons.image_outlined,
                color: _showImages ? _accentColor : null,
              ),
            ),
            IconButton(
              tooltip: 'Pul berish',
              onPressed: _openPaymentSheet,
              icon: const Icon(Icons.payments_outlined),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 44),
            child: Column(
              children: [
                _buildYukUserChips(),
                TabBar(
                  isScrollable: true,
                  labelColor: _accentColor,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: _accentColor,
                  tabs: _tabs.map((id) => Tab(text: _tabName(id))).toList(),
                ),
              ],
            ),
          ),
        ),
        body: Consumer<BugalterProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.orders.isEmpty) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (provider.errorMessage != null && provider.orders.isEmpty) {
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
                        provider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.fetchOrders(),
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

            return TabBarView(
              children: _tabs.map((id) {
                var orders = provider.forSklad(id);
                // Yuk keltiruvchi filtri (tepadagi chiplar).
                if (_selectedYukUserId != null) {
                  orders = orders
                      .where((o) => o.pricedBy == _selectedYukUserId)
                      .toList();
                }
                // Buyurtmalar KUNLIK kartalarga jamlanadi (buyurtma IDlarisiz):
                // hech narsa ko'rsatmaydigan (bo'sh) buyurtmalar tashlanadi,
                // qolganlari lokal kalendar kuni bo'yicha guruhlanadi.
                final days =
                    _groupByDay(orders.where(_orderContributes).toList());
                return RefreshIndicator(
                  color: _accentColor,
                  onRefresh: () => provider.fetchOrders(),
                  child: days.isEmpty
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: days.length + 1,
                          itemBuilder: (context, index) {
                            // Tepada tab bo'yicha qisqa yig'indi.
                            if (index == 0) {
                              return _TabSummary(orders: orders);
                            }
                            final day = days[index - 1];
                            return _BugalterDayCard(
                              key: ValueKey(day.day),
                              day: day.day,
                              orders: day.orders,
                              showImages: _showImages,
                              // "Hammasi" tabida sklad almashganda kichik
                              // sklad nomi yorlig'i ko'rsatiladi.
                              showSkladLabels: id == null,
                            );
                          },
                        ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

// "Pul berish" bottom sheet'i: yuk keltiruvchi tanlanadi, summa va
// ixtiyoriy izoh kiritiladi, "Berish" bosilganda POST /api/payments ketadi.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet();

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const Color _accent = Color(0xFFC5A97B);

  YukUser? _selectedUser;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // "1 234 567" -> 1234567 (probellarni olib tashlab parse qilamiz).
  int get _amount =>
      int.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;

  Future<void> _submit() async {
    final user = _selectedUser;
    final amount = _amount;
    if (user == null) {
      _showSnack('Yuk keltiruvchini tanlang', isError: true);
      return;
    }
    if (amount <= 0) {
      _showSnack('Summani kiriting', isError: true);
      return;
    }

    final provider = context.read<BugalterProvider>();
    // Sheet yopilgandan keyin ham snackbar ko'rinishi uchun messenger'ni
    // await'dan OLDIN olib qo'yamiz (pop'dan keyin context ishlamaydi).
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await provider.submitPayment(
        userId: user.id,
        amount: amount,
        comment: _commentController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
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

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Klaviatura ochilganda sheet ko'tarilishi uchun.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Consumer<BugalterProvider>(
        builder: (context, provider, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pul berish',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // Yuk keltiruvchi tanlash.
              if (provider.isLoadingYukUsers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              else if (provider.yukUsersError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.yukUsersError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => provider.fetchYukUsers(),
                        child: const Text(
                          'Qayta urinish',
                          style: TextStyle(color: _accent),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<YukUser>(
                  initialValue: _selectedUser,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Yuk keltiruvchi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent, width: 2),
                    ),
                  ),
                  items: provider.yukUsers
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u.phone.isNotEmpty
                                ? '${u.name} (${u.phone})'
                                : u.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedUser = v),
                ),
              const SizedBox(height: 12),
              // Summa (faqat raqam, ming ajratuvchi probel bilan).
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Summa',
                  suffixText: 'so\'m',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Izoh (ixtiyoriy).
              TextField(
                controller: _commentController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Izoh (ixtiyoriy)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: provider.isSubmittingPayment ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: provider.isSubmittingPayment
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Berish',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Summalarni chiroyli ko'rsatish: 1000 -> "1 000" (yuk_home_ui bilan bir xil).
String _money(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtQty(double v) {
  if (v == 0) return '0';
  var s = v.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

// ─────────────── Kunlik guruhlash yordamchilari ───────────────

// Bir kunlik guruh: lokal kalendar kuni va shu kunga tegishli buyurtmalar.
class _DayGroup {
  final DateTime day;
  final List<YukOrder> orders;
  _DayGroup(this.day, this.orders);
}

// Buyurtma qaysi kunga tegishli: narxlangan vaqti (priced_at), bo'lmasa
// yaratilgan vaqti — LOKAL kalendar kuni sifatida.
DateTime _orderDay(YukOrder o) {
  final dt = o.pricedAt ?? DateTime.tryParse(o.created);
  if (dt == null) return DateTime(2000);
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

// Buyurtmaning ko'rsatiladigan mahsulot qatorlari: rasxod emas va
// "olinmagan"/bo'sh (taken == 0 && subtotal == 0) qatorlar tashlanadi.
List<YukOrderItem> _visibleProducts(YukOrder o) => o.items
    .where((i) => !i.isRasxod && !(i.taken == 0 && i.subtotal == 0))
    .toList();

// Buyurtma kunlik kartaga biror narsa qo'shadimi: ko'rinadigan mahsulot
// qatori, rasxod yoki nol bo'lmagan summa bo'lsa — ha. Hammasi bo'sh
// buyurtma umuman ko'rsatilmaydi.
bool _orderContributes(YukOrder o) =>
    _visibleProducts(o).isNotEmpty ||
    o.items.any((i) => i.isRasxod) ||
    o.total != 0;

// Buyurtmalarni kunlar bo'yicha guruhlash; kunlar kamayuvchi tartibda
// (eng yangi kun birinchi). Kun ichida kelgan tartib saqlanadi.
List<_DayGroup> _groupByDay(List<YukOrder> orders) {
  final map = <DateTime, List<YukOrder>>{};
  for (final o in orders) {
    map.putIfAbsent(_orderDay(o), () => []).add(o);
  }
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final k in keys) _DayGroup(k, map[k]!)];
}

// Tab tepasidagi yig'indi: shu tabdagi jami mahsulot va jami xarajat.
class _TabSummary extends StatelessWidget {
  final List<YukOrder> orders;
  const _TabSummary({required this.orders});

  static const Color _accent = Color(0xFFC5A97B);

  @override
  Widget build(BuildContext context) {
    double products = 0, expenses = 0;
    for (final o in orders) {
      products += o.total.toDouble();
      expenses += o.expensesTotal;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mahsulot',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_money(products)} so\'m',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Xarajat',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_money(expenses)} so\'m',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fayl/URL video ekanini kengaytmasidan aniqlash (yuk_home_ui bilan bir xil).
bool _isVideoPath(String p) {
  final ext = p.split('.').last.toLowerCase();
  return const {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'}.contains(ext);
}

// Relativ /static/... URL'ni to'liq manzilga aylantirish.
String _attachmentUrl(String url) =>
    url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';

// Bitta KUN kartasi: sarlavha — faqat sana (dd.MM.yyyy, buyurtma ID va
// statussiz), shu kunning barcha buyurtmalari mahsulot qatorlari bitta
// jadvalda (jamlanmaydi, ketma-ket), xarajatlar (rasxod) kun bo'yicha
// jamlangan blok va kun yakuni (Mahsulot/Xarajat/Jami).
class _BugalterDayCard extends StatelessWidget {
  final DateTime day;
  // Shu kunga tegishli (bo'sh bo'lmagan) buyurtmalar.
  final List<YukOrder> orders;
  // true bo'lsa buyurtmalarga biriktirilgan rasm/videolar ko'rsatiladi
  // (AppBar'dagi tugma bilan boshqariladi).
  final bool showImages;
  // "Hammasi" tabida sklad almashganda kichik sklad nomi yorlig'i chiqadi;
  // aniq sklad tabida kerak emas.
  final bool showSkladLabels;
  const _BugalterDayCard({
    super.key,
    required this.day,
    required this.orders,
    this.showImages = false,
    this.showSkladLabels = false,
  });

  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    // Kun bo'yicha jami: totalSum — narxlangan to'liq summa; effectiveSum —
    // ombor kam qabul qilgan buyurtmada receivedTotal, aks holda total.
    double totalSum = 0, effectiveSum = 0, expenses = 0;
    var hasProducts = false;
    for (final o in orders) {
      final received = o.receivedTotal;
      final orderReduced =
          received > 0 && (received - o.total).abs() > 0.0001;
      totalSum += o.total.toDouble();
      effectiveSum += orderReduced ? received : o.total.toDouble();
      expenses += o.expensesTotal;
      if (_visibleProducts(o).isNotEmpty) hasProducts = true;
    }
    // Kun darajasida kamaygan bo'lsa — eski summa ustidan chizilib,
    // yangisi yashil ko'rsatiladi.
    final reduced = (effectiveSum - totalSum).abs() > 0.0001;
    // Kunning barcha buyurtmalaridagi rasxod (xarajat) qatorlari — bitta blok.
    final rasxodItems = [
      for (final o in orders) ...o.items.where((i) => i.isRasxod),
    ];
    final grandTotal = effectiveSum + expenses;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarlavha: faqat kun sanasi (buyurtma ID va status ko'rsatilmaydi).
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd.MM.yyyy').format(day),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          // Jadval sarlavhasi (mahsulot qatorlari bo'lsa).
          if (hasProducts)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Mahsulot',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Soni',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Donasi',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Turi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Summa',
                    textAlign: TextAlign.right,
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
          // Kunning barcha buyurtmalari qatorlari (sklad yorlig'i,
          // biriktirmalar va mahsulotlar — kelgan tartibda, jamlanmasdan).
          ..._buildDayRows(),
          // Xarajatlar (rasxod) bloki.
          if (rasxodItems.isNotEmpty) ...[
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
            ...rasxodItems.map(
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
                      '${_money(item.subtotal)} so\'m',
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
          const Divider(height: 18),
          // Kun yakuni: Mahsulot / Xarajat (bo'lsa) / Jami. Ombor kam qabul
          // qilgan bo'lsa eski summa chizilib, effektiv summa yashil chiqadi.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mahsulot:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              if (!reduced)
                Text(
                  '${_money(effectiveSum)} so\'m',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_money(totalSum)} so\'m',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _red,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _red,
                        decorationThickness: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_money(effectiveSum)} so\'m',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (expenses > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Xarajat:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  '${_money(expenses)} so\'m',
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
                '${_money(grandTotal)} so\'m',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Kun kartasining ichki qatorlari: har buyurtma uchun (kelgan tartibda)
  // — "Hammasi" tabida sklad almashsa kichik sklad yorlig'i, buyurtma
  // biriktirmalari (rasm tugmasi yoqiq bo'lsa) va mahsulot qatorlari
  // (har qator ostida omborchi qabul paytidagi media — acceptMedia).
  List<Widget> _buildDayRows() {
    final out = <Widget>[];
    String? lastSklad;
    for (final order in orders) {
      final products = _visibleProducts(order);
      final skladName = order.skladName.isNotEmpty
          ? order.skladName
          : (_skladNames[order.skladId] ?? 'Sklad ${order.skladId}');
      // Sklad yorlig'i faqat "Hammasi" tabida va sklad almashganda.
      if (showSkladLabels && skladName != lastSklad) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                const Icon(Icons.store_outlined, size: 14, color: _accent),
                const SizedBox(width: 4),
                Text(
                  skladName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        );
        lastSklad = skladName;
      }
      // Buyurtmaga biriktirilgan rasm/videolar (AppBar tugmasi yoqilganda).
      if (showImages && order.attachments.isNotEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: order.attachments
                  .map((e) => _AttachmentTile(entry: e))
                  .toList(),
            ),
          ),
        );
      }
      for (final item in products) {
        out.add(_productRow(item));
        // Omborchi qabul paytida olgan rasm/video (tugma yoqilganda).
        if (showImages && item.acceptMedia.isNotEmpty) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.acceptMedia
                    .map((e) => _AttachmentTile(entry: e, size: 56))
                    .toList(),
              ),
            ),
          );
        }
      }
    }
    return out;
  }

  // Bitta mahsulot qatori: Mahsulot / Soni / Donasi / Turi / Summa.
  Widget _productRow(YukOrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              _fmtQty(item.taken),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Donasi (birlik narx) = summa / soni.
          Expanded(
            flex: 3,
            child: Text(
              item.taken > 0 && item.subtotal > 0
                  ? '${_money(item.subtotal / item.taken)} so\'m'
                  : '-',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Turi (o'lchov birligi: кг, шт...).
          Expanded(
            flex: 2,
            child: Text(
              (item.type ?? '').isNotEmpty ? item.type! : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              '${_money(item.subtotal)} so\'m',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bitta biriktirma plitkasi (72x72): rasm — thumbnail (bosilsa to'liq ekran),
// video — play belgisi (bosilsa tashqi pleerda ochiladi).
class _AttachmentTile extends StatelessWidget {
  final String entry;
  final double size;
  const _AttachmentTile({required this.entry, this.size = 72});

  void _open(BuildContext context) {
    if (_isVideoPath(entry)) {
      launchUrl(
        Uri.parse(_attachmentUrl(entry)),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(_attachmentUrl(entry)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoPath(entry);
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isVideo
              ? Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                )
              : Image.network(
                  _attachmentUrl(entry),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF5F1EA),
                    child: const Icon(Icons.broken_image, color: Colors.black26),
                  ),
                ),
        ),
      ),
    );
  }
}
