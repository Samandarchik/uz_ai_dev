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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BugalterProvider>().fetchOrders();
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
          bottom: TabBar(
            isScrollable: true,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.black54,
            indicatorColor: _accentColor,
            tabs: _tabs.map((id) => Tab(text: _tabName(id))).toList(),
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
                final orders = provider.forSklad(id);
                return RefreshIndicator(
                  color: _accentColor,
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: orders.length + 1,
                          itemBuilder: (context, index) {
                            // Tepada tab bo'yicha qisqa yig'indi.
                            if (index == 0) {
                              return _TabSummary(orders: orders);
                            }
                            final order = orders[index - 1];
                            return _BugalterOrderCard(
                              key: ValueKey(order.id),
                              order: order,
                              showImages: _showImages,
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

String _formatDate(String raw) {
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
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

// Bitta buyurtma kartasi: sarlavha (order_id, sklad, sana, status),
// mahsulotlar jadvali, xarajatlar bloki va chek yakuni.
class _BugalterOrderCard extends StatelessWidget {
  final YukOrder order;
  // true bo'lsa buyurtmaga biriktirilgan rasm/videolar ko'rsatiladi
  // (AppBar'dagi tugma bilan boshqariladi).
  final bool showImages;
  const _BugalterOrderCard({
    super.key,
    required this.order,
    this.showImages = false,
  });

  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);
  static const Color _blue = Color(0xFF1565C0);

  bool get _isAccepted => order.status == 'qabul_qilindi';

  @override
  Widget build(BuildContext context) {
    // Mahsulot qatorlari (rasxod chek oxirida alohida).
    final productItems = order.items.where((i) => !i.isRasxod).toList();
    final rasxodItems = order.items.where((i) => i.isRasxod).toList();

    final received = order.receivedTotal;
    final reduced = received > 0 && (received - order.total).abs() > 0.0001;
    final effectiveMahsulot = reduced ? received : order.total.toDouble();
    final expenses = order.expensesTotal;
    final grandTotal = effectiveMahsulot + expenses;

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
              _statusChip(),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.store_outlined, size: 16, color: _accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.skladName.isNotEmpty
                      ? order.skladName
                      : (_skladNames[order.skladId] ?? 'Sklad ${order.skladId}'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _formatDate(order.created),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          // Biriktirilgan rasm/videolar (AppBar tugmasi yoqilganda).
          if (showImages && order.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: order.attachments
                  .map((e) => _AttachmentTile(entry: e))
                  .toList(),
            ),
          ],
          const Divider(height: 18),
          // Jadval sarlavhasi.
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
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
          ...productItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
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
            ),
          ),
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
          // Chek yakuni: Mahsulot / Xarajat (bo'lsa) / Jami.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mahsulot:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              if (!reduced)
                Text(
                  '${_money(order.total)} so\'m',
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
                      '${_money(order.total)} so\'m',
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
                      '${_money(received)} so\'m',
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

  Widget _statusChip() {
    final bg = _isAccepted
        ? _green.withValues(alpha: 0.12)
        : _blue.withValues(alpha: 0.12);
    final fg = _isAccepted ? _green : _blue;
    final label = _isAccepted ? 'Qabul qilindi' : 'Narxlandi';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

// Bitta biriktirma plitkasi (72x72): rasm — thumbnail (bosilsa to'liq ekran),
// video — play belgisi (bosilsa tashqi pleerda ochiladi).
class _AttachmentTile extends StatelessWidget {
  final String entry;
  const _AttachmentTile({required this.entry});

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
      width: 72,
      height: 72,
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
