import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/agent/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin_agent/ui/admin_add_categoriy.dart';
import 'package:uz_ai_dev/admin_agent/ui/admin_product_ui.dart';
import 'package:uz_ai_dev/admin_agent/ui/user_management_screen.dart';
import 'package:uz_ai_dev/login_page.dart';

class AdminHomeUiAgent extends StatefulWidget {
  const AdminHomeUiAgent({super.key});

  @override
  State<AdminHomeUiAgent> createState() => _AdminHomeUiAgentState();
}

class _AdminHomeUiAgentState extends State<AdminHomeUiAgent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // Kategoriyalar va barcha mahsulotlarni bir marta yuklash
  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    final categoryProvider = context.read<CategoryProviderAdminAgent>();
    final ProductProviderAgent = context.read<ProductProviderAgentAdmin>();

    // Parallel ravishda yuklash
    await Future.wait([
      categoryProvider.getCategories(),
      ProductProviderAgent.initializeProducts(forceRefresh: forceRefresh),
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
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadInitialData(forceRefresh: true),
            tooltip: 'Yangilash',
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
      body: Consumer2<CategoryProviderAdminAgent, ProductProviderAgentAdmin>(
        builder: (context, categoryProvider, ProductProviderAgent, child) {
          // Loading holati
          if ((categoryProvider.isLoading &&
                  categoryProvider.categories.isEmpty) ||
              (ProductProviderAgent.isLoading &&
                  !ProductProviderAgent.isInitialized)) {
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

          return RefreshIndicator(
            onRefresh: () => _loadInitialData(forceRefresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: categoryProvider.categories.length,
              itemBuilder: (context, index) {
                final category = categoryProvider.categories[index];

                // Har bir kategoriya uchun mahsulotlar sonini hisoblash
                final productCount =
                    ProductProviderAgent.getProductCountByCategory(category.id);

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
                                    "${AppUrlsAgent.baseUrl}${category.imageUrl}",
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
                                  "${AppUrlsAgent.baseUrl}${category.imageUrl}",
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    context.push(
                      AdminProductUi(
                        categoryId: category.id,
                        categoryName: category.name,
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
