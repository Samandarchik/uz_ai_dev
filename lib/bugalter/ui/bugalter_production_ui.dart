import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/production/provider/production_orders_provider.dart';
import 'package:uz_ai_dev/production/ui/widgets/production_order_widgets.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';
import 'package:uz_ai_dev/shef/ui/shef_home_ui.dart' show productionStatusChip;

// Bugalter: BARCHA ishlab chiqarish buyurtmalari. Faqat bugalterga xos
// amallar: buyurtmani O'CHIRISH va STATUSNI qo'lda almashtirish
// (yangi/jarayonda/tayyor) — bu ikkalasi shef/admin'da ham yo'q.
class BugalterProductionUi extends StatefulWidget {
  const BugalterProductionUi({super.key});

  @override
  State<BugalterProductionUi> createState() => _BugalterProductionUiState();
}

class _BugalterProductionUiState extends State<BugalterProductionUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  BugalterProductionProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<BugalterProductionProvider>();
      provider.fetchOrders();
      provider.connectSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<BugalterProductionProvider>();
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
      body: Consumer<BugalterProductionProvider>(
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
                              builder: (_) => BugalterProductionDetailUi(
                                  orderId: order.id),
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

// Buyurtma tafsiloti + bugalter amallari (AppBar): statusni o'zgartirish
// va o'chirish.
class BugalterProductionDetailUi extends StatefulWidget {
  final int orderId;

  const BugalterProductionDetailUi({super.key, required this.orderId});

  @override
  State<BugalterProductionDetailUi> createState() =>
      _BugalterProductionDetailUiState();
}

class _BugalterProductionDetailUiState
    extends State<BugalterProductionDetailUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BugalterProductionProvider>().refreshOrder(widget.orderId);
    });
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // «O'chirish» — tasdiq dialogi bilan; muvaffaqiyatda ro'yxatga qaytadi.
  Future<void> _delete() async {
    final order = context
        .read<BugalterProductionProvider>()
        .orderById(widget.orderId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buyurtmani o\'chirish',
            style: TextStyle(fontSize: 17)),
        content: Text(
          '${order == null || order.orderId.isEmpty ? '№${widget.orderId}' : order.orderId} '
          'buyurtmasi butunlay o\'chiriladi. Davom etilsinmi?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final err = await context
        .read<BugalterProductionProvider>()
        .deleteOrder(widget.orderId);
    if (!mounted) return;
    if (err != null) {
      _snack(err);
      return;
    }
    _snack('Buyurtma o\'chirildi', error: false);
    Navigator.pop(context);
  }

  // «Statusni o'zgartirish» — radio dialog (yangi/jarayonda/tayyor).
  Future<void> _changeStatus() async {
    final provider = context.read<BugalterProductionProvider>();
    final order = provider.orderById(widget.orderId);
    if (order == null) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _StatusDialog(current: order.status),
    );
    if (picked == null || picked == order.status || !mounted) return;

    final err = await provider.setStatus(widget.orderId, picked);
    if (!mounted) return;
    if (err != null) {
      _snack(err);
    } else {
      _snack('Status yangilandi', error: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BugalterProductionProvider>(
      builder: (context, provider, child) {
        final order = provider.orderById(widget.orderId);
        final busy = provider.busyOrderId == widget.orderId;

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
              if (order != null && busy)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (order != null) ...[
                Center(child: productionStatusChip(order.status)),
                IconButton(
                  onPressed: _changeStatus,
                  tooltip: 'Statusni o\'zgartirish',
                  icon: const Icon(Icons.sync_alt),
                ),
                IconButton(
                  onPressed: _delete,
                  tooltip: 'O\'chirish',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ],
          ),
          body: order == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : RefreshIndicator(
                  onRefresh: () => provider.refreshOrder(widget.orderId),
                  child: ProductionOrderDetailBody(order: order),
                ),
        );
      },
    );
  }
}

// Status tanlash dialogi (radio: yangi / jarayonda / tayyor).
class _StatusDialog extends StatefulWidget {
  final String current;

  const _StatusDialog({required this.current});

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  late String _selected;

  static const Map<String, String> _labels = {
    ProductionStatus.yangi: 'Yangi',
    ProductionStatus.jarayonda: 'Jarayonda',
    ProductionStatus.tayyor: 'Tayyor',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Statusni o\'zgartirish',
          style: TextStyle(fontSize: 17)),
      content: RadioGroup<String>(
        groupValue: _selected,
        onChanged: (v) {
          if (v != null) setState(() => _selected = v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _labels.entries)
              RadioListTile<String>(
                value: entry.key,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    Text(entry.value, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}
