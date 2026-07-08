import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/ui/admin_production_stats_ui.dart';
import 'package:uz_ai_dev/bugalter/provider/bugalter_provider.dart';
import 'package:uz_ai_dev/bugalter/ui/bugalter_production_ui.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/ui/widgets/yuk_day_cards.dart';

// Kunlik kartalar (YukDayCard), guruhlash va sklad nomlari — yuk tarixi
// ekrani bilan UMUMIY: yuk/ui/widgets/yuk_day_cards.dart.

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
  static final List<int?> _tabs = [null, ...kYukSkladNames.keys];

  // AppBar'dagi tugma bilan yoqiladi: buyurtmaga biriktirilgan
  // rasm/videolarni kartada ko'rsatish.
  bool _showImages = false;

  // Yuk keltiruvchi bo'yicha filtr (null -> hammasi). Buyurtma priced_by
  // maydoni bilan solishtiriladi.
  int? _selectedYukUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BugalterProvider>().fetchOrders();
      // Tepadagi filtr chiplari uchun yuk keltiruvchilar ro'yxati.
      context.read<BugalterProvider>().fetchYukUsers();
    });
  }

  void _logout() {
    tokenStorage.removeToken();
    tokenStorage.removeRefreshToken();
    context.push(LoginPage());
  }

  String _tabName(int? id) =>
      id == null ? 'Hammasi' : (kYukSkladNames[id] ?? 'Sklad $id');

  // Sklad tablari tepasidagi yuk keltiruvchi filtri: "Hammasi" + har bir
  // yuk keltiruvchi nomi. Tanlanganda buyurtmalar priced_by bo'yicha
  // filtrlanadi.
  Widget _buildYukUserChips() {
    return Consumer<BugalterProvider>(
      builder: (context, provider, _) {
        if (provider.yukUsers.isEmpty) return const SizedBox(height: 44);
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final entry in <int?, String>{
                null: 'Hammasi',
                for (final u in provider.yukUsers) u.id: u.name,
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _selectedYukUserId == entry.key,
                    onSelected: (_) =>
                        setState(() => _selectedYukUserId = entry.key),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selectedYukUserId == entry.key
                          ? Colors.white
                          : Colors.black54,
                    ),
                    selectedColor: _accentColor,
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: _selectedYukUserId == entry.key
                          ? _accentColor
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

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
            // Ishlab chiqarish buyurtmalari (o'chirish + status — faqat bugalter).
            IconButton(
              tooltip: 'Ishlab chiqarish',
              onPressed: () => context.push(const BugalterProductionUi()),
              icon: const Icon(Icons.factory_outlined),
            ),
            // Ishlab chiqarish statistikasi (backend bugalterga ham ochiq).
            IconButton(
              tooltip: 'Ishlab chiqarish statistikasi',
              onPressed: () => context.push(const AdminProductionStatsUi()),
              icon: const Icon(Icons.query_stats),
            ),
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
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 44),
            child: Column(
              children: [
                _buildYukUserChips(),
                TabBar(
                  isScrollable: true,
                  labelColor: _accentColor,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: _accentColor,
                  tabs: _tabs.map((id) => Tab(text: _tabName(id))).toList(),
                ),
              ],
            ),
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
                var orders = provider.forSklad(id);
                // Yuk keltiruvchi filtri (tepadagi chiplar).
                if (_selectedYukUserId != null) {
                  orders = orders
                      .where((o) => o.pricedBy == _selectedYukUserId)
                      .toList();
                }
                // Buyurtmalar KUNLIK kartalarga jamlanadi (buyurtma IDlarisiz):
                // hech narsa ko'rsatmaydigan (bo'sh) buyurtmalar tashlanadi,
                // qolganlari lokal kalendar kuni bo'yicha guruhlanadi.
                final days = groupYukOrdersByDay(
                    orders.where(yukOrderContributes).toList());
                return RefreshIndicator(
                  color: _accentColor,
                  onRefresh: () => provider.fetchOrders(),
                  child: days.isEmpty
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
                          itemCount: days.length + 1,
                          itemBuilder: (context, index) {
                            // Tepada tab bo'yicha qisqa yig'indi.
                            if (index == 0) {
                              return _TabSummary(orders: orders);
                            }
                            final day = days[index - 1];
                            return YukDayCard(
                              key: ValueKey(day.day),
                              day: day.day,
                              orders: day.orders,
                              showImages: _showImages,
                              // "Hammasi" tabida sklad almashganda kichik
                              // sklad nomi yorlig'i ko'rsatiladi.
                              showSkladLabels: id == null,
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
                  '${formatMoney(products)} so\'m',
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
                  '${formatMoney(expenses)} so\'m',
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
