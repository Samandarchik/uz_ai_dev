import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/bringer/ui/bringer_tasks_ui.dart';
import 'package:uz_ai_dev/bringer/ui/bringer_orders_ui.dart';
import 'package:uz_ai_dev/bringer/ui/bringer_balance_ui.dart';
import 'package:uz_ai_dev/bringer/ui/bringer_active_order_ui.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';

class BringerHomeUi extends StatefulWidget {
  final int bringerProfileId;

  const BringerHomeUi({super.key, required this.bringerProfileId});

  @override
  State<BringerHomeUi> createState() => _BringerHomeUiState();
}

class _BringerHomeUiState extends State<BringerHomeUi> {
  final TokenStorage tokenStorage = sl<TokenStorage>();
  String name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BringerProvider>();
      provider.setSelectedBringerProfile(widget.bringerProfileId);
      _loadData(provider);
    });
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('name')?.replaceAll('"', '') ?? '';
    });
  }

  Future<void> _loadData(BringerProvider provider) async {
    await Future.wait([
      provider.loadActiveOrder(),
      provider.loadBalance(),
      provider.loadTasks(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: () {
              tokenStorage.removeToken();
              tokenStorage.removeRefreshToken();
              context.pushAndRemove(const LoginPage());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => _loadData(provider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balans kartasi
                _buildBalanceCard(provider),
                const SizedBox(height: 16),

                // Aktiv order
                if (provider.activeOrder != null) ...[
                  _buildActiveOrderCard(provider),
                  const SizedBox(height: 16),
                ],

                // Menu
                _buildMenuTile(
                  icon: Icons.checklist,
                  title: 'Olish ro\'yxati',
                  subtitle: '${provider.tasks.length} ta mahsulot',
                  color: Colors.orange,
                  onTap: () => context.push(BringerTasksUi(
                    bringerProfileId: widget.bringerProfileId,
                  )),
                ),
                const SizedBox(height: 8),
                _buildMenuTile(
                  icon: Icons.shopping_bag,
                  title: 'Xaridlar tarixi',
                  subtitle: 'Barcha orderlar',
                  color: Colors.blue,
                  onTap: () => context.push(BringerOrdersUi(
                    bringerProfileId: widget.bringerProfileId,
                  )),
                ),
                const SizedBox(height: 8),
                _buildMenuTile(
                  icon: Icons.account_balance_wallet,
                  title: 'Balans tarixi',
                  subtitle: 'Kirim-chiqim',
                  color: Colors.green,
                  onTap: () => context.push(BringerBalanceUi(
                    bringerProfileId: widget.bringerProfileId,
                  )),
                ),
                const SizedBox(height: 16),

                // Yangi xarid boshlash
                if (provider.activeOrder == null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final success = await provider
                                  .createOrder();
                              if (success && context.mounted) {
                                context.push(BringerActiveOrderUi(
                                  bringerProfileId: widget.bringerProfileId,
                                ));
                              }
                            },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Yangi xarid boshlash',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BringerProvider provider) {
    final balance = provider.balance;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Balans',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '${_formatMoney(balance?.availableBalance ?? 0)} so\'m',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (balance != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Umumiy: ${_formatMoney(balance.totalBalance)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Sarflangan: ${_formatMoney(balance.spentBalance)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(BringerProvider provider) {
    final order = provider.activeOrder!;
    return Card(
      color: Colors.blue.shade50,
      child: InkWell(
        onTap: () => context.push(BringerActiveOrderUi(
          bringerProfileId: widget.bringerProfileId,
        )),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.blue, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktiv xarid: ${order.orderID}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order.items.length} ta mahsulot | ${_formatMoney(order.total)} so\'m',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ');
  }
}
