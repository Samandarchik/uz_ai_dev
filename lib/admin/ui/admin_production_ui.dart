import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/production/provider/production_orders_provider.dart';
import 'package:uz_ai_dev/production/provider/stock_provider.dart';
import 'package:uz_ai_dev/production/ui/widgets/production_order_widgets.dart';
import 'package:uz_ai_dev/shef/ui/shef_home_ui.dart' show productionStatusChip;

// Admin: BARCHA ishlab chiqarish buyurtmalari (faqat ko'rish — «Berdim»,
// o'chirish, status almashtirish yo'q). Kartada sklad + shef ko'rinadi.
class AdminProductionUi extends StatefulWidget {
  const AdminProductionUi({super.key});

  @override
  State<AdminProductionUi> createState() => _AdminProductionUiState();
}

class _AdminProductionUiState extends State<AdminProductionUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  AdminProductionProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminProductionProvider>();
      provider.fetchOrders();
      provider.connectSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<AdminProductionProvider>();
  }

  @override
  void dispose() {
    _provider?.disconnectSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Ishlab chiqarish buyurtmalari',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<AdminProductionProvider>(
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

          return RefreshIndicator(
            color: _accentColor,
            onRefresh: () => provider.fetchOrders(),
            child: provider.orders.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 160),
                      Center(
                        child: Text(
                          'Ishlab chiqarish buyurtmalari yo\'q',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: provider.orders.length,
                    itemBuilder: (context, index) {
                      final order = provider.orders[index];
                      return ProductionOrderCard(
                        order: order,
                        showShef: true,
                        showSklad: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminProductionDetailUi(orderId: order.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

// Buyurtma tafsiloti (read-only): ombordagi bilan bir xil ko'rinish —
// bo'limlar, masalliqlar jadvali (qoldiq bilan) — lekin «Berdim» yo'q.
class AdminProductionDetailUi extends StatefulWidget {
  final int orderId;

  const AdminProductionDetailUi({super.key, required this.orderId});

  @override
  State<AdminProductionDetailUi> createState() =>
      _AdminProductionDetailUiState();
}

class _AdminProductionDetailUiState extends State<AdminProductionDetailUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);

  int? _stockLoadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProductionProvider>().refreshOrder(widget.orderId);
      _ensureStock();
    });
  }

  // Buyurtma skladining qoldig'ini yuklash (admin istalgan skladni ko'radi).
  void _ensureStock() {
    final order =
        context.read<AdminProductionProvider>().orderById(widget.orderId);
    if (order == null || order.skladId == 0) return;
    if (_stockLoadedFor == order.skladId) return;
    _stockLoadedFor = order.skladId;
    final stock = context.read<StockProvider>();
    if (stock.stockFor(order.skladId) == null) {
      stock.fetchStock(order.skladId);
    } else {
      stock.refreshSilently(order.skladId);
    }
  }

  Future<void> _refreshAll() async {
    final provider = context.read<AdminProductionProvider>();
    await provider.refreshOrder(widget.orderId);
    final order = provider.orderById(widget.orderId);
    if (order != null && order.skladId != 0 && mounted) {
      await context.read<StockProvider>().refreshSilently(order.skladId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AdminProductionProvider, StockProvider>(
      builder: (context, provider, stockProvider, child) {
        final order = provider.orderById(widget.orderId);
        if (order != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureStock();
          });
        }

        return Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            title: Text(
              order == null || order.orderId.isEmpty
                  ? 'Buyurtma'
                  : order.orderId,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (order != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(child: productionStatusChip(order.status)),
                ),
            ],
          ),
          body: order == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: ProductionOrderDetailBody(
                    order: order,
                    stockQtyOf: (productId) =>
                        stockProvider.qtyFor(order.skladId, productId),
                  ),
                ),
        );
      },
    );
  }
}
