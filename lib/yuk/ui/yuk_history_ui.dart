import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_home_ui.dart';

// Yuborilgan (narxlangan / omborchi qabul qilgan) buyurtmalar tarixi.
// Asosiy sahifadagi AppBar'dagi tarix tugmasidan ochiladi; skladlar bo'yicha
// tablar, har tabда o'sha skladning yuborilgan buyurtmalari (yangisi tepada).
class YukHistoryUi extends StatelessWidget {
  final List<int> sklads;
  const YukHistoryUi({super.key, required this.sklads});

  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  String _skladName(int id) => kSkladNames[id] ?? 'Sklad $id';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: sklads.length,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Yuborilganlar tarixi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          bottom: sklads.isEmpty
              ? null
              : TabBar(
                  isScrollable: sklads.length > 2,
                  labelColor: _accentColor,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: _accentColor,
                  tabs: sklads.map((id) => Tab(text: _skladName(id))).toList(),
                ),
        ),
        body: sklads.isEmpty
            ? const Center(
                child: Text(
                  'Sizga hech qanday sklad biriktirilmagan',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            : Consumer<YukProvider>(
                builder: (context, provider, child) {
                  return TabBarView(
                    children: sklads.map((id) {
                      final orders = provider.doneForSklad(id);
                      return RefreshIndicator(
                        onRefresh: () => provider.fetchOrders(),
                        child: orders.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Yuborilgan buyurtmalar yo\'q',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: orders.length,
                                itemBuilder: (context, index) => YukOrderCard(
                                  // Buyurtma holati o'zgarganda (masalan undo)
                                  // karta state'i qayta qurilishi uchun.
                                  key: ValueKey(orders[index].id),
                                  order: orders[index],
                                ),
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
