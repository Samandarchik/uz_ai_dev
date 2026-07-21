// ombor/ui/ombor_low_stock_ui.dart — Ombor: min chegaradan past (kam qolgan) mahsulotlar sahifasi:
// OmborLowStockUi (OmborProvider + StockProvider). Kartadan savatga qo'shib shu yerdan buyurtma qilinadi.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_category_products_ui.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/provider/stock_provider.dart';

// Ombor: min chegaradan pastga tushgan (low) mahsulotlar sahifasi.
// Kartochka bosilsa savatga qo'shiladi — yetishmayotgan mahsulotni shu
// yerdan turib buyurtma qilish mumkin (pastda savat paneli).
// Chegara TAHRIRI bu yerda yo'q — u «Qoldiq» sahifasida.
class OmborLowStockUi extends StatefulWidget {
  const OmborLowStockUi({super.key});

  @override
  State<OmborLowStockUi> createState() => _OmborLowStockUiState();
}

class _OmborLowStockUiState extends State<OmborLowStockUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  void initState() {
    super.initState();
    // Skladlar + qoldiqlar (kesh bor bo'lsa so'rov ketmaydi).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ensureOmborStock(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sklads = context.watch<OmborProvider>().skladIds;

    if (sklads.isEmpty) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Kam qolganlar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sizga hech qanday sklad biriktirilmagan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    // Bitta sklad — tabsiz oddiy ro'yxat.
    if (sklads.length == 1) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: Text(
            'Kam qolganlar — ${productionSkladName(sklads.first)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: _LowStockSkladView(skladId: sklads.first),
        bottomNavigationBar: const OmborCartBar(),
      );
    }

    // Bir nechta sklad — tablar (Qoldiq sahifasidagi kabi).
    return DefaultTabController(
      length: sklads.length,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Kam qolganlar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            isScrollable: sklads.length > 2,
            indicatorColor: _accentColor,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.black54,
            tabs: sklads.map((id) => Tab(text: productionSkladName(id))).toList(),
          ),
        ),
        body: TabBarView(
          children:
              sklads.map((id) => _LowStockSkladView(skladId: id)).toList(),
        ),
        bottomNavigationBar: const OmborCartBar(),
      ),
    );
  }
}

// Bitta skladning kam qolgan mahsulotlari. Katalogda bor mahsulot ->
// OmborProductCard (bosilsa savatga qo'shiladi), yo'q bo'lsa -> oddiy plitka.
class _LowStockSkladView extends StatelessWidget {
  final int skladId;

  const _LowStockSkladView({required this.skladId});

  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();
    final ombor = context.watch<OmborProvider>();

    final rows = stock.stockFor(skladId);
    final error = stock.errorFor(skladId);

    if (stock.isLoading(skladId) && rows == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (error != null && rows == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => stock.fetchStock(skladId),
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

    // Eng yomoni yuqorida: qty/min_qty nisbati o'suvchi tartibda.
    final low = (rows ?? const <StockRow>[]).where((r) => r.low).toList()
      ..sort((a, b) => _shortfall(a).compareTo(_shortfall(b)));

    return RefreshIndicator(
      color: _accentColor,
      onRefresh: () => stock.fetchStock(skladId),
      child: low.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 140),
                Center(
                  child: Text(
                    'Hammasi yetarli ✅',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            )
          : GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: low.length,
              itemBuilder: (context, index) {
                final row = low[index];
                final product = ombor.findProductById(row.productId);
                // Bozor katalogida yo'q mahsulot — buyurtma qilib bo'lmaydi.
                if (product == null) return _LowStockTile(row: row);
                return OmborProductCard(
                  product: product,
                  isGrid: true,
                  skladId: skladId,
                );
              },
            ),
    );
  }

  // Chegaraga nisbatan yetishmovchilik: kichik qiymat = yomonroq holat.
  // min_qty > 0 (low qatorlarida doim shunday), manfiy qoldiq eng oldinda.
  double _shortfall(StockRow r) => r.minQty > 0 ? r.qty / r.minQty : 0;
}

// Katalogda yo'q mahsulot uchun faqat o'qish plitkasi: nomi + qoldiq qatori.
class _LowStockTile extends StatelessWidget {
  final StockRow row;

  const _LowStockTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final color = Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400, size: 28),
          const SizedBox(height: 8),
          Text(
            row.name.isEmpty ? 'Mahsulot #${row.productId}' : row.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  omborQoldiqText(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          // Berilgan, lekin hali kelmagan buyurtma (0 bo'lsa ko'rinmaydi).
          OmborBuyurtmaLabel(
            productId: row.productId,
            type: row.type,
            padding: const EdgeInsets.only(top: 4),
          ),
        ],
      ),
    );
  }
}
