import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_category_products_ui.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_orders_ui.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_production_ui.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_stock_ui.dart';

// Ombor roli uchun bosh ekran — user panelidagi kabi: tepada qidiruv,
// har kategoriya sarlavha + "barchasi" tugmasi + gorizontal kartochkalar.
class OmborHomeUi extends StatefulWidget {
  const OmborHomeUi({super.key});

  @override
  State<OmborHomeUi> createState() => _OmborHomeUiState();
}

class _OmborHomeUiState extends State<OmborHomeUi>
    with SingleTickerProviderStateMixin {
  final TokenStorage tokenStorage = sl<TokenStorage>();

  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  late final TabController _tabController;

  // dispose() ichida context.read() xavfsiz emas (widget deaktiv bo'lishi mumkin),
  // shuning uchun provider referensini didChangeDependencies'da saqlaymiz.
  OmborProvider? _omborProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OmborProvider>();
      provider.fetchProducts();
      // Real-time: ro'yxat refresh'siz avtomatik yangilanishi uchun socketga ulanamiz.
      provider.connectSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _omborProvider = context.read<OmborProvider>();
  }

  @override
  void dispose() {
    // Ekrandan chiqishda real-time ulanishni uzamiz (saqlangan referens orqali).
    _omborProvider?.disconnectSocket();
    _tabController.dispose();
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
          'Ombor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Ishlab chiqarish buyurtmalari (shef → ombor masalliq berish).
          IconButton(
            onPressed: () {
              context.push(const OmborProductionUi());
            },
            tooltip: 'Ishlab chiqarish',
            icon: const Icon(Icons.factory_outlined),
          ),
          // Sklad qoldig'i (inventar) sahifasi.
          IconButton(
            onPressed: () {
              context.push(const OmborStockUi());
            },
            tooltip: 'Qoldiq',
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          // Qabul qilingan buyurtmalar tarixi (yuk keltiruvchidagi kabi).
          IconButton(
            onPressed: () {
              context.push(const OmborOrdersHistoryUi());
            },
            tooltip: 'Qabul qilinganlar tarixi',
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () {
              // Logout: avval socketni uzamiz.
              context.read<OmborProvider>().disconnectSocket();
              tokenStorage.removeToken();
              tokenStorage.removeRefreshToken();
              context.push(LoginPage());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accentColor,
          labelColor: _accentColor,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Mahsulotlar'),
            Tab(text: 'Buyurtmalarim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OmborProductsTab(),
          OmborOrdersView(),
        ],
      ),
      // Savatcha bar faqat "Mahsulotlar" tabида (index 0) ko'rinadi.
      bottomNavigationBar: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (context, child) {
          final isProductsTab = (_tabController.animation!.value).round() == 0;
          if (!isProductsTab) return const SizedBox.shrink();
          return const OmborCartBar();
        },
      ),
    );
  }
}

// "Mahsulotlar" tabи — user panelidagi bosh ekran kabi: qidiruv maydoni,
// kategoriya sarlavhasi + "barchasi" tugmasi va gorizontal kartochkalar.
class _OmborProductsTab extends StatefulWidget {
  const _OmborProductsTab();

  @override
  State<_OmborProductsTab> createState() => _OmborProductsTabState();
}

class _OmborProductsTabState extends State<_OmborProductsTab> {
  static const Color _accentColor = Color(0xFFC5A97B);

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OmborProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchProducts(),
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

        final categories = provider.orderedCategories;
        if (categories.isEmpty) {
          return const Center(child: Text('Mahsulotlar topilmadi'));
        }

        final query = _searchQuery.toLowerCase();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Mahsulot qidirish...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.grey),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.fetchProducts(),
                child: ListView.builder(
                  // Pastdagi savat paneli mahsulotlarni to'smasligi uchun joy.
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final allProducts =
                        provider.productsByCategory[category.name] ?? [];

                    final products = query.isEmpty
                        ? allProducts
                        : allProducts.where((p) {
                            return p.name.toLowerCase().contains(query) ||
                                category.name.toLowerCase().contains(query);
                          }).toList();

                    if (products.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.push(OmborCategoryProductsUi(
                                      categoryName: category.name,
                                    ));
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                          color: Colors.grey.shade400,
                                          width: 1),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'barchasi',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.chevron_right,
                                          color: Colors.black54, size: 18),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 280,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: products.length,
                              itemBuilder: (context, pIndex) =>
                                  OmborProductCard(product: products[pIndex]),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
