import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';

// Sklad nomlari (loyihaning boshqa joylarida ham shu hardcode map ishlatiladi).
const Map<int, String> kSkladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
};

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

  @override
  void initState() {
    super.initState();
    _loadSklads();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<YukProvider>().fetchOrders();
    });
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
        body: Consumer<YukProvider>(
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

            return TabBarView(
              children: _sklads.map((id) {
                final orders = provider.ordersForSklad(id);
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: orders.length,
                          itemBuilder: (context, index) =>
                              _YukOrderCard(order: orders[index]),
                        ),
                );
              }).toList(),
            );
          },
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
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      bottom: bottom,
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
// Har item qatorida INLINE narx maydonlari (Nechpuldan / Jami summa),
// pastida "Chek bilan yuborish" tugmasi.
class _YukOrderCard extends StatefulWidget {
  final YukOrder order;
  const _YukOrderCard({required this.order});

  @override
  State<_YukOrderCard> createState() => _YukOrderCardState();
}

class _YukOrderCardState extends State<_YukOrderCard> {
  static const Color _accentColor = Color(0xFFC5A97B);

  // Har bir item (product_id) uchun narx va jami controllerlari.
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, TextEditingController> _subtotalControllers = {};

  // Ochiq (narx maydonlari ko'rinadigan) itemlarning product_id lari.
  final Set<int> _expanded = {};

  YukOrder get order => widget.order;

  String _fmt(double v) {
    if (v == 0) return '';
    return v.toStringAsFixed(0);
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<YukProvider>();
    for (final item in order.items) {
      final existing = provider.getItemPrice(order.id, item.productId);
      _priceControllers[item.productId] =
          TextEditingController(text: existing != null ? _fmt(existing.price) : '');
      _subtotalControllers[item.productId] = TextEditingController(
          text: existing != null ? _fmt(existing.subtotal) : '');
      // Allaqachon narxlangan item default OCHIQ ko'rsatiladi.
      if (existing != null && existing.price > 0) {
        _expanded.add(item.productId);
      }
    }
  }

  void _toggleExpanded(int productId) {
    setState(() {
      if (_expanded.contains(productId)) {
        _expanded.remove(productId);
      } else {
        _expanded.add(productId);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _subtotalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Bo'sh yoki noto'g'ri bo'lsa 0 qaytaradi.
  double _parse(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null || v < 0) return 0;
    return v;
  }

  void _onItemChanged(int productId) {
    final provider = context.read<YukProvider>();
    final price = _parse(_priceControllers[productId]?.text ?? '');
    final subtotal = _parse(_subtotalControllers[productId]?.text ?? '');
    provider.setItemPrice(order.id, productId, price, subtotal);
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

  // Inline kichik narx maydoni.
  Widget _inlineField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black54),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<YukProvider>(
      builder: (context, provider, child) {
        final hasAnyPrice = provider.hasAnyPrice(order.id);
        final orderTotal = provider.orderTotal(order.id);
        final submitting = provider.submittingOrderId == order.id;

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
                ],
              ),
              const Divider(height: 18),
              ...order.items.map((item) {
                final isOpen = _expanded.contains(item.productId);
                final priced =
                    provider.getItemPrice(order.id, item.productId);
                final hasPrice = priced != null && priced.price > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatCount(item.count)}'
                                  '${item.type != null && item.type!.isNotEmpty ? ' ${item.type}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                // Yopiq bo'lsa va narx kiritilgan bo'lsa qisqa ko'rinish.
                                if (!isOpen && hasPrice) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatMoney(priced.price)} so\'mdan • '
                                    '${_formatMoney(priced.subtotal)} so\'m',
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
                          const SizedBox(width: 8),
                          // Toggle tugma: ochish/yopish.
                          Material(
                            color: isOpen
                                ? _accentColor
                                : _accentColor.withValues(alpha: 0.12),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _toggleExpanded(item.productId),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  isOpen ? Icons.close : Icons.add,
                                  size: 18,
                                  color:
                                      isOpen ? Colors.white : _accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Narx maydonlari FAQAT ochiq bo'lganda.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: isOpen
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _inlineField(
                                        controller:
                                            _priceControllers[item.productId]!,
                                        label: 'Nechpuldan',
                                        onChanged: (_) =>
                                            _onItemChanged(item.productId),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _inlineField(
                                        controller: _subtotalControllers[
                                            item.productId]!,
                                        label: 'Jami summa',
                                        onChanged: (_) =>
                                            _onItemChanged(item.productId),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 18),
              Row(
                children: [
                  const Text(
                    'Jami:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatMoney(orderTotal)} so\'m',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                                content: Text('Omborga yuborildi'),
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
                      : const Icon(Icons.receipt_long, size: 18),
                  label: Text(submitting ? 'Yuborilmoqda...' : 'Chek bilan yuborish'),
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
