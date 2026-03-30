import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/bringer/ui/bringer_purchased_ui.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';

class BringerActiveOrderUi extends StatefulWidget {
  final int bringerProfileId;

  const BringerActiveOrderUi({super.key, required this.bringerProfileId});

  @override
  State<BringerActiveOrderUi> createState() => _BringerActiveOrderUiState();
}

class _BringerActiveOrderUiState extends State<BringerActiveOrderUi>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BringerProvider>();
      provider.loadActiveOrder();
      provider.loadTasks();
      provider.loadProducts(widget.bringerProfileId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Sotib olish dialogi — miqdor, 1 dona narx, to'liq summa (auto-sync)
  void _showPurchaseDialog({
    required String name,
    required int productId,
    String? imageUrl,
    String? type,
    double? initialCount,
    String? subtitle,
  }) {
    final countController = TextEditingController(
        text: (initialCount ?? 1).toStringAsFixed(
            initialCount != null && initialCount != initialCount.toInt()
                ? 1
                : 0));
    final priceController = TextEditingController();
    final totalController = TextEditingController();
    final commentController = TextEditingController();

    bool updatingFromPrice = false;
    bool updatingFromTotal = false;

    void recalcTotal() {
      if (updatingFromTotal) return;
      updatingFromPrice = true;
      final count = double.tryParse(countController.text) ?? 0;
      final price = int.tryParse(priceController.text) ?? 0;
      if (count > 0 && price > 0) {
        totalController.text = (count * price).toInt().toString();
      }
      updatingFromPrice = false;
    }

    void recalcPrice() {
      if (updatingFromPrice) return;
      updatingFromTotal = true;
      final count = double.tryParse(countController.text) ?? 0;
      final total = int.tryParse(totalController.text) ?? 0;
      if (count > 0 && total > 0) {
        priceController.text = (total / count).round().toString();
      }
      updatingFromTotal = false;
    }

    countController.addListener(recalcTotal);
    priceController.addListener(recalcTotal);
    totalController.addListener(recalcPrice);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: "${AppUrls.baseUrl}$imageUrl",
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: countController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Miqdor (${type ?? ""})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '1 dona/kg narxi (so\'m)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'To\'liq summa (so\'m)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Izoh (ixtiyoriy)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor'),
            ),
            ElevatedButton(
              onPressed: () async {
                final count = double.tryParse(countController.text);
                final price = int.tryParse(priceController.text);
                if (count == null ||
                    count <= 0 ||
                    price == null ||
                    price <= 0) {
                  return;
                }
                Navigator.pop(ctx);
                await context.read<BringerProvider>().addOrderItem(
                      productId: productId,
                      count: count,
                      price: price,
                      comment: commentController.text.isEmpty
                          ? null
                          : commentController.text,
                    );
                if (mounted) {
                  context.read<BringerProvider>().loadTasks();
                }
              },
              child: const Text('Sotib oldim'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktiv xarid'),
        actions: [
          Consumer<BringerProvider>(
            builder: (context, provider, _) {
              final order = provider.activeOrder;
              if (order != null && order.items.isNotEmpty) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push(const BringerPurchasedUi()),
                      icon: Badge(
                        label: Text('${order.items.length}'),
                        child:
                            const Icon(Icons.shopping_bag, color: Colors.green),
                      ),
                      label: Text(
                        _formatMoney(order.total),
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final success = await provider.pushOrder();
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Order yuborildi!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                      icon: const Icon(Icons.send, color: Colors.blue),
                      label: const Text('Yuborish',
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          if (provider.activeOrder == null) {
            return const Center(child: Text('Aktiv order yo\'q'));
          }

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Olish kerak (${provider.tasks.length})'),
                  Tab(text: 'Barcha mahsulotlar'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(provider),
                    _buildProductList(provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== OLISH KERAK (TASKS) ====================
  Widget _buildTaskList(BringerProvider provider) {
    if (provider.tasks.isEmpty) {
      return const Center(child: Text('Vazifalar yo\'q'));
    }
    return RefreshIndicator(
      onRefresh: () => provider.loadTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: provider.tasks.length,
        itemBuilder: (context, index) {
          final task = provider.tasks[index];
          return Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: task.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: "${AppUrls.baseUrl}${task.imageUrl}",
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.shopping_bag),
                      )
                    : const SizedBox(
                        width: 45, height: 45, child: Icon(Icons.shopping_bag)),
              ),
              title: Text(task.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                'Kerak: ${task.remainingCount.toStringAsFixed(1)} ${task.type}',
                style: TextStyle(color: Colors.red.shade700),
              ),
              onTap: () => _showPurchaseDialog(
                name: task.name,
                productId: task.productID,
                imageUrl: task.imageUrl,
                type: task.type,
                initialCount: task.remainingCount,
                subtitle:
                    'Kerak: ${task.requiredCount.toStringAsFixed(1)} ${task.type} | Qolgan: ${task.remainingCount.toStringAsFixed(1)} ${task.type}',
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== BARCHA MAHSULOTLAR (seller UI kabi) ====================
  Widget _buildProductList(BringerProvider provider) {
    final categories = provider.productsByCategory;
    if (categories.isEmpty) {
      return const Center(child: Text('Mahsulotlar yo\'q'));
    }
    return RefreshIndicator(
      onRefresh: () => provider.loadProducts(widget.bringerProfileId),
      child: ListView(
        padding: EdgeInsets.zero,
        children: categories.entries.map((entry) {
          final categoryName = entry.key;
          final products = entry.value;
          // Kategoriya — bosganda mahsulotlar listini ochadi
          return ExpansionTile(
            title: Text(
              categoryName,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${products.length} ta mahsulot'),
            children: products.map((product) {
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: ClipOval(
                  child: product.imageUrl != null &&
                          product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.image),
                        )
                      : Container(
                          width: 45,
                          height: 45,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image)),
                ),
                title: Text(product.name),
                trailing: Text(product.type ?? '',
                    style: TextStyle(color: Colors.grey.shade600)),
                onTap: () => _showPurchaseDialog(
                  name: product.name,
                  productId: product.id,
                  imageUrl: product.imageUrl,
                  type: product.type,
                  subtitle: product.category,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ');
  }
}
