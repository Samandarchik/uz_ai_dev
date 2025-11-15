import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';
import 'package:uz_ai_dev/user/ui/order_ui.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/user/ui/orders_page.dart';
import 'package:uz_ai_dev/user/ui/product_ui.dart';

// Kategoriyalar ekrani
class UserHomeUi extends StatefulWidget {
  const UserHomeUi({super.key});

  @override
  _UserHomeUiState createState() => _UserHomeUiState();
}

class _UserHomeUiState extends State<UserHomeUi> {
  TokenStorage tokenStorage = sl<TokenStorage>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchCategories();
      context.read<ProductProvider>().fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => _showContactDialog(context),
            icon: Icon(Icons.info_outline)),
        title: Text('Категории',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                tokenStorage.removeToken();
                tokenStorage.removeRefreshToken();
                context.push(LoginPage());
              },
              icon: Icon(Icons.logout)),
          IconButton(
              onPressed: () => context.push(OrdersPage()),
              icon: Icon(Icons.receipt_long)),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Ошибка: ${provider.errorMessage}'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: provider.categories.length,
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  // product sonini tekshiramiz
                  final productCount =
                      provider.getProductsByCategory(category.name).length;

                  if (productCount == 0) {
                    // Hech qanday product bo‘lmasa, kategoriya chiqmasin
                    return SizedBox.shrink();
                  }

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductsScreen(
                            categoryName: category.name,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                      ),
                      leading: ClipOval(
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: CachedNetworkImage(
                                  imageUrl:
                                      "${AppUrls.baseUrl}${category.imageUrl}",
                                  fit: BoxFit.contain,
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.error, size: 40),
                                ),
                              ),
                            );
                          },
                          child: CachedNetworkImage(
                            imageUrl: "${AppUrls.baseUrl}${category.imageUrl}",
                            width: 55,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Icon(Icons.error),
                          ),
                        ),
                      ),
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "$productCount продукт",
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.totalSelectedProducts > 0) {
            return FloatingActionButton.extended(
              onPressed: () async {
                context.push(CartPage());
              },
              icon: Icon(Icons.shopping_basket_outlined),
              label: Text(provider.totalSelectedProducts.toStringAsFixed(3)),
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Вопрос или проблема'),
          content: Text(
              'Если у вас возник вопрос или вам что-то непонятно, обратитесь к создателю программы.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _launchContactLink();
              },
              child: Text('Контакт'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchContactLink() async {
    const urlString = 'https://t.me/uz_ai_dev';
    final Uri url = Uri.parse(urlString);
    // launchUrl funktsiyasidan foydalanamiz
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // agar ochilmasa, xatolik ko‘rsating
      throw 'Could not launch $url';
    }
  }
}
