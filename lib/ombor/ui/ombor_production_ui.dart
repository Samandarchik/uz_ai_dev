import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/production/provider/production_orders_provider.dart';
import 'package:uz_ai_dev/production/provider/stock_provider.dart';
import 'package:uz_ai_dev/production/ui/widgets/production_order_widgets.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';
import 'package:uz_ai_dev/shef/ui/shef_home_ui.dart' show productionStatusChip;

// Ombor: o'z skladiga kelgan ishlab chiqarish buyurtmalari ro'yxati.
// Har karta: order_id, sana, shef nomi, mahsulotlar qisqacha, status chip.
class OmborProductionUi extends StatefulWidget {
  const OmborProductionUi({super.key});

  @override
  State<OmborProductionUi> createState() => _OmborProductionUiState();
}

class _OmborProductionUiState extends State<OmborProductionUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  OmborProductionProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OmborProductionProvider>();
      provider.fetchOrders();
      // Real-time: shef yangi buyurtma berganda ro'yxat refresh'siz yangilanadi.
      provider.connectSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose() ichida context.read() xavfsiz emas — referensni saqlaymiz.
    _provider = context.read<OmborProductionProvider>();
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
          'Ishlab chiqarish',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<OmborProductionProvider>(
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
                          'Hozircha ishlab chiqarish buyurtmalari yo\'q',
                          textAlign: TextAlign.center,
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OmborProductionDetailUi(orderId: order.id),
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

// Buyurtma tafsiloti: har mahsulot, har bo'lim uchun masalliqlar jadvali
// (nomi | kerak | qoldiq | yetadimi) va «Berdim» tugmasi. Rad etilgan bo'lim
// qizil, izoh bilan — qayta «Berdim» mumkin.
class OmborProductionDetailUi extends StatefulWidget {
  final int orderId;

  const OmborProductionDetailUi({super.key, required this.orderId});

  @override
  State<OmborProductionDetailUi> createState() =>
      _OmborProductionDetailUiState();
}

class _OmborProductionDetailUiState extends State<OmborProductionDetailUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);

  // Qoldiq qaysi sklad uchun yuklangan (order kelgach bir marta).
  int? _stockLoadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OmborProductionProvider>().refreshOrder(widget.orderId);
      _ensureStock();
    });
  }

  // Buyurtma skladining qoldig'ini yuklash (order hali kelmagan bo'lsa
  // build'dagi Consumer keyingi kadrda yana chaqiradi).
  void _ensureStock() {
    final order =
        context.read<OmborProductionProvider>().orderById(widget.orderId);
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
    final provider = context.read<OmborProductionProvider>();
    await provider.refreshOrder(widget.orderId);
    final order = provider.orderById(widget.orderId);
    if (order != null && order.skladId != 0 && mounted) {
      await context.read<StockProvider>().refreshSilently(order.skladId);
    }
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // «Berdim»: tasdiq dialogi (qoldiq yetmasa ogohlantirish bilan), keyin
  // issue + qoldiqni yangilash.
  Future<void> _issue(ProductionItem item, int pi, int si) async {
    final provider = context.read<OmborProductionProvider>();
    final stockProvider = context.read<StockProvider>();
    final order = provider.orderById(widget.orderId);
    if (order == null) return;

    final stage = item.stages[si];
    final shorts = shortIngredients(
      stage,
      (productId) => stockProvider.qtyFor(order.skladId, productId),
    );
    final unlinked =
        stage.ingredients.where((i) => !i.linked).toList(growable: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Berdim — tasdiqlash',
            style: TextStyle(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.name}\n${si + 1}-bo\'lim: ${stage.name}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bo\'lim masalliqlari skladdan chiqim qilinadi.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (shorts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Qoldiq yetmaydi:\n'
                '${shorts.map((i) => '• ${i.name}').join('\n')}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Qoldiq manfiyga tushishi mumkin. Baribir berilsinmi?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
            if (unlinked.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Qoldiqqa bog\'lanmagan (chiqim qilinmaydi):\n'
                '${unlinked.map((i) => '• ${i.name}').join('\n')}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: shorts.isEmpty ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Berdim'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final err = await provider.issueStage(widget.orderId, pi, si);
    if (!mounted) return;
    if (err != null) {
      _snack(err);
      return;
    }
    _snack('Masalliq berildi', error: false);
    // Chiqim qoldiqni o'zgartirdi — qoldiqni jim yangilaymiz.
    final fresh = provider.orderById(widget.orderId);
    if (fresh != null && fresh.skladId != 0) {
      stockProvider.refreshSilently(fresh.skladId);
    }
  }

  // «Berdim» tugmasi: material_status "" yoki rad_etildi bo'lganda.
  // (Consumer2 provider o'zgarishida butun body'ni qayta quradi, shuning
  // uchun bu yerda read yetarli.)
  Widget? _stageAction(ProductionItem item, int pi, int si) {
    final provider = context.read<OmborProductionProvider>();
    final stage = item.stages[si];
    final canIssue = stage.materialStatus == MaterialStatus.none ||
        stage.materialStatus == MaterialStatus.radEtildi;
    if (!canIssue) return null;

    final busy = provider.busyStageKey ==
        OmborProductionProvider.stageKey(widget.orderId, pi, si);
    if (busy) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // Boshqa bo'limda amal ketayotgan bo'lsa tugma o'chiq turadi.
    final anyBusy = provider.busyStageKey != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: anyBusy ? null : () => _issue(item, pi, si),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.outbox_outlined, size: 18),
        label: Text(
          stage.materialStatus == MaterialStatus.radEtildi
              ? 'Qayta berdim'
              : 'Berdim',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OmborProductionProvider, StockProvider>(
      builder: (context, provider, stockProvider, child) {
        final order = provider.orderById(widget.orderId);
        // Order endi keldi-yu qoldiq hali yuklanmagan bo'lishi mumkin.
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
                    stageAction: _stageAction,
                  ),
                ),
        );
      },
    );
  }
}
