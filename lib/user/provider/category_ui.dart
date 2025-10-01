import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/user/provider/order_ui.dart';
import 'package:uz_ai_dev/user/provider/product_ui.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';
import 'package:uz_ai_dev/user/ui/screens/login_page.dart';

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
        title: Text('categories'.tr(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                tokenStorage.removeToken();
                tokenStorage.removeRefreshToken();
                context.push(LoginPage());
              },
              icon: Icon(Icons.logout))
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Xatolik: ${provider.errorMessage}'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return ListView.builder(
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

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
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
                        contentPadding: EdgeInsets.all(5),
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
                              imageUrl:
                                  "${AppUrls.baseUrl}${category.imageUrl}",
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
                          "$productCount ${"product".tr()}",
                        ),
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
                // try {
                //   // Loading dialog
                //   showDialog(
                //     context: context,
                //     barrierDismissible: false,
                //     builder: (context) => Center(
                //       child: CircularProgressIndicator(),
                //     ),
                //   );

                //   // await provider.submitOrder();

                //   Navigator.pop(context); // Close loading dialog

                //   // Success message
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(
                //       content: Text('Buyurtma muvaffaqiyatli yuborildi!'),
                //       backgroundColor: Colors.green,
                //     ),
                //   );
                // } catch (e) {
                //   Navigator.pop(context); // Close loading dialog

                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(
                //       content: Text('Xatolik: $e'),
                //       backgroundColor: Colors.red,
                //     ),
                //   );
                // }
              },
              icon: Icon(Icons.shopping_basket_outlined),
              label: Text('(${provider.totalSelectedProducts})'),
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }
}
