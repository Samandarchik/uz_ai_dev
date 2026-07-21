// admin/ui/admin_stock_ui.dart — sklad qoldiqlari ekrani (AdminStockUi):
// har sklad uchun tab (StockSkladView, canAdjust=true) — korreksiya va harakatlar
// tarixi; joriy tab uchun inventarizatsiya (StockInventoryPage). Qoldiq StockProvider'da.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/ui/inventory_page.dart';
import 'package:uz_ai_dev/production/ui/widgets/stock_widgets.dart';

// Admin: sklad qoldiqlari — har sklad uchun tab (loyihadagi boshqa
// ekranlardagi kabi 1..4 hardcode), korreksiya kiritish va harakatlar tarixi.
class AdminStockUi extends StatelessWidget {
  const AdminStockUi({super.key});

  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  Widget build(BuildContext context) {
    final skladIds = kProductionSkladNames.keys.toList();

    return DefaultTabController(
      length: skladIds.length,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Sklad qoldiqlari',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Joriy tab skladi uchun inventarizatsiya.
            Builder(
              builder: (tabContext) => IconButton(
                tooltip: 'Inventarizatsiya',
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () {
                  final index = DefaultTabController.of(tabContext).index;
                  Navigator.push(
                    tabContext,
                    MaterialPageRoute(
                      builder: (_) =>
                          StockInventoryPage(skladId: skladIds[index]),
                    ),
                  );
                },
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: _accentColor,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.black54,
            tabs: skladIds
                .map((id) => Tab(text: productionSkladName(id)))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: skladIds
              .map((id) => StockSkladView(skladId: id, canAdjust: true))
              .toList(),
        ),
      ),
    );
  }
}
