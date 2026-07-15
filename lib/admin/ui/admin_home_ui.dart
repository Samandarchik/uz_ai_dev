import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/ui/admin_add_categoriy.dart';
import 'package:uz_ai_dev/admin/ui/admin_product_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_production_stats_ui.dart';
import 'package:uz_ai_dev/admin/ui/profit_control_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_production_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_stock_ui.dart';
import 'package:uz_ai_dev/admin/ui/user_management_screen.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';

class AdminHomeUi extends StatefulWidget {
  const AdminHomeUi({super.key});

  @override
  State<AdminHomeUi> createState() => _AdminHomeUiState();
}

class _AdminHomeUiState extends State<AdminHomeUi> {
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // Kategoriyalar va barcha mahsulotlarni bir marta yuklash
  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    final categoryProvider = context.read<CategoryProviderAdmin>();
    final productProvider = context.read<ProductProviderAdmin>();

    // Parallel ravishda yuklash
    await Future.wait([
      categoryProvider.getCategories(),
      productProvider.initializeProducts(forceRefresh: forceRefresh),
    ]);
  }

  TokenStorage tokenStorage = sl<TokenStorage>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.push(UserManagementScreen()),
          icon: const Icon(Icons.people),
        ),
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            onPressed: () {
              final productProvider = context.read<ProductProviderAdmin>();
              showSearch(
                context: context,
                delegate: _AdminProductSearchDelegate(productProvider),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.menu),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'categories',
                child: ListTile(
                  leading: Icon(Icons.category),
                  title: Text('Kategoriyalar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'production',
                child: ListTile(
                  leading: Icon(Icons.factory_outlined),
                  title: Text('Ishlab chiqarish'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'production_stats',
                child: ListTile(
                  leading: Icon(Icons.query_stats),
                  title: Text('Ishlab chiqarish statistikasi'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'stock',
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Sklad qoldiqlari'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'profit_control',
                child: ListTile(
                  leading: Icon(Icons.trending_up),
                  title: Text('Foyda nazorati'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'categories':
                  context.push(const CategoryManagementScreen());
                  break;
                case 'production':
                  context.push(const AdminProductionUi());
                  break;
                case 'production_stats':
                  context.push(const AdminProductionStatsUi());
                  break;
                case 'stock':
                  context.push(const AdminStockUi());
                  break;
                case 'profit_control':
                  context.push(const ProfitControlUi());
                  break;
              }
            },
          ),
          IconButton(
            onPressed: () {
              tokenStorage.removeToken();
              context.pushAndRemove(const LoginPage());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Consumer2<CategoryProviderAdmin, ProductProviderAdmin>(
        builder: (context, categoryProvider, productProvider, child) {
          // Loading holati
          if ((categoryProvider.isLoading &&
                  categoryProvider.categories.isEmpty) ||
              (productProvider.isLoading && !productProvider.isInitialized)) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          // Xatolik holati
          if (categoryProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Ошибка: ${categoryProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadInitialData(forceRefresh: true),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          // Bo'sh holat
          if (categoryProvider.categories.isEmpty) {
            return const Center(child: Text('Kategoriyalar topilmadi'));
          }

          if (_isEditMode) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: categoryProvider.categories.length,
              onReorderItem: (oldIndex, newIndex) {
                categoryProvider.reorderCategories(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final category = categoryProvider.categories[index];
                return ListTile(
                  key: ValueKey(category.id),
                  contentPadding: EdgeInsets.zero,
                  leading: ClipOval(
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
                  title: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.drag_handle,
                    size: 24,
                    color: Colors.grey,
                  ),
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadInitialData(forceRefresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: categoryProvider.categories.length,
              itemBuilder: (context, index) {
                final category = categoryProvider.categories[index];

                final productCount =
                    productProvider.getProductCountByCategory(category.id);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipOval(
                    child: GestureDetector(
                      onTap: () {
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
                    'ID: ${category.id} • $productCount продукт',
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
                    context.push(AdminProductUi(
                      categoryId: category.id,
                      categoryName: category.name,
                    ));
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

class _AdminProductSearchDelegate extends SearchDelegate<String> {
  final ProductProviderAdmin productProvider;

  _AdminProductSearchDelegate(this.productProvider)
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
    final results = query.isEmpty
        ? <ProductModelAdmin>[]
        : productProvider.products.where((p) {
            final q = query.toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                p.categoryName.toLowerCase().contains(q) ||
                (p.companyName?.toLowerCase().contains(q) ?? false);
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
      itemCount: results.length,
      itemBuilder: (context, index) {
        final product = results[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported),
                  ),
          ),
          title: Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${product.categoryName} • ${product.type}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            close(context, '');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminProductUi(
                  categoryId: product.categoryId,
                  categoryName: product.categoryName,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
