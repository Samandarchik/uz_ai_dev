import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_category_products_ui.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_orders_ui.dart';

// Ombor roli uchun bosh ekran — admin paneldagi kabi: avval kategoriyalar
// ro'yxati, kategoriya bosilganda ichidagi mahsulotlar ochiladi.
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
          // Admin paneldagi kabi qidiruv: barcha mahsulotlar bo'yicha.
          IconButton(
            onPressed: () {
              final provider = context.read<OmborProvider>();
              showSearch(
                context: context,
                delegate: _OmborProductSearchDelegate(provider),
              );
            },
            icon: const Icon(Icons.search),
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
          _OmborCategoriesTab(),
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

// "Mahsulotlar" tabи mazmuni: admin paneldagi kabi kategoriyalar ro'yxati
// (dumaloq rasm + nom + mahsulot soni). Bosilganda kategoriya sahifasi ochiladi.
class _OmborCategoriesTab extends StatelessWidget {
  const _OmborCategoriesTab();

  static const Color _accentColor = Color(0xFFC5A97B);

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

        return RefreshIndicator(
          onRefresh: () => provider.fetchProducts(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final productCount = provider.productCount(category.name);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipOval(
                  child: GestureDetector(
                    onTap: () {
                      // Admin paneldagi kabi: rasm bosilsa katta ko'rinadi.
                      if (category.imageUrl != null) {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: CachedNetworkImage(
                              imageUrl:
                                  "${AppUrls.baseUrl}${category.imageUrl}",
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) =>
                                  const Icon(
                                Icons.error,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: category.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl:
                                "${AppUrls.baseUrl}${category.imageUrl}",
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.image_not_supported),
                          )
                        : Container(
                            width: 55,
                            height: 55,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image_not_supported),
                          ),
                  ),
                ),
                title: Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '$productCount ta mahsulot',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  context.push(
                    OmborCategoryProductsUi(categoryName: category.name),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Admin paneldagi kabi qidiruv oynasi. Natijadagi mahsulotni shu yerning
// o'zida savatga qo'shish mumkin (+/- stepper saqlanadi).
class _OmborProductSearchDelegate extends SearchDelegate<String> {
  final OmborProvider provider;

  _OmborProductSearchDelegate(this.provider)
      : super(searchFieldLabel: 'Mahsulot qidirish...');

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, ''),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    final q = query.toLowerCase();
    final results = q.isEmpty
        ? <MapEntry<String, OmborProduct>>[]
        : provider.allProductsWithCategory.where((entry) {
            return entry.value.name.toLowerCase().contains(q) ||
                entry.key.toLowerCase().contains(q);
          }).toList();

    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Mahsulot nomini kiriting',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Hech narsa topilmadi',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            OmborProductTile(product: entry.value),
          ],
        );
      },
    );
  }
}
