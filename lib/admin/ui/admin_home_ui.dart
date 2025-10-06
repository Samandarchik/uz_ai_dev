import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/ui/admin_add_categoriy.dart';
import 'package:uz_ai_dev/admin/ui/admin_product_ui.dart';
import 'package:uz_ai_dev/admin/ui/user_management_screen.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/user/ui/login_page.dart';

class AdminHomeUi extends StatefulWidget {
  const AdminHomeUi({super.key});

  @override
  State<AdminHomeUi> createState() => _AdminHomeUiState();
}

class _AdminHomeUiState extends State<AdminHomeUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    final categoryProvider = context.read<CategoryProviderAdmin>();
    await categoryProvider.getCategories();
  }

  TokenStorage tokenStorage = sl<TokenStorage>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.push(UserManagementScreen()),
            icon: Icon(Icons.people)),
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
            onPressed: _loadCategories,
          ),
          IconButton(
              onPressed: () {
                tokenStorage.removeToken();
                context.pushAndRemove(const LoginPage());
              },
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: Consumer<CategoryProviderAdmin>(
        builder: (context, categoryProvider, child) {
          if (categoryProvider.isLoading &&
              categoryProvider.categories.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

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
                    onPressed: _loadCategories,
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (categoryProvider.categories.isEmpty) {
            return const Center(child: Text('Kategoriyalar topilmadi'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: categoryProvider.categories.length,
            itemBuilder: (context, index) {
              final category = categoryProvider.categories[index];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipOval(
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: CachedNetworkImage(
                            imageUrl: "${AppUrls.baseUrl}${category.imageUrl}",
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) => const Icon(
                                Icons.error,
                                size: 40,
                                color: Colors.white),
                          ),
                        ),
                      );
                    },
                    child: category.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: "${AppUrls.baseUrl}${category.imageUrl}",
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
                  'ID: ${category.id}',
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
          );
        },
      ),
    );
  }
}
