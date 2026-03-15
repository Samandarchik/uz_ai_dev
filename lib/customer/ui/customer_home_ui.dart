import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/customer/provider/customer_provider.dart';
import 'package:uz_ai_dev/customer/ui/customer_cart_ui.dart';
import 'package:uz_ai_dev/customer/ui/customer_orders_ui.dart';
import 'package:uz_ai_dev/customer/ui/customer_product_ui.dart';
import 'package:uz_ai_dev/login_page.dart';

class CustomerHomeUi extends StatefulWidget {
  const CustomerHomeUi({super.key});

  @override
  State<CustomerHomeUi> createState() => _CustomerHomeUiState();
}

class _CustomerHomeUiState extends State<CustomerHomeUi> {
  TokenStorage tokenStorage = sl<TokenStorage>();
  String name = '';

  Future<void> getMe() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('name') ?? '';
    if (!mounted) return;
    setState(() {
      name = savedName;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCategories();
      context.read<CustomerProvider>().fetchProducts();
    });
    getMe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => _showContactDialog(context),
            icon: Icon(Icons.info_outline)),
        title: Text(name,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                tokenStorage.removeToken();
                tokenStorage.removeRefreshToken();
                context.pushAndRemove(LoginPage());
              },
              icon: Icon(Icons.logout)),
          IconButton(
              onPressed: () => context.push(CustomerOrdersUi()),
              icon: Icon(Icons.receipt_long)),
        ],
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Xatolik: ${provider.errorMessage}'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: provider.categories.length,
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  final productCount =
                      provider.getProductsByCategory(category.name).length;

                  if (productCount == 0) {
                    return SizedBox.shrink();
                  }

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerProductsScreen(
                            categoryName: category.name,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 6),
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
                      subtitle: Text("$productCount mahsulot"),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.totalSelectedProducts > 0) {
            return FloatingActionButton.extended(
              onPressed: () async {
                context.push(CustomerCartUi());
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
          title: Text('Savol yoki muammo'),
          content: Text(
              'Savolingiz bo\'lsa yoki tushunarsiz narsa bo\'lsa, dastur yaratuvchisiga murojaat qiling.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Bekor'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _launchContactLink();
              },
              child: Text('Aloqa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchContactLink() async {
    const urlString = 'https://t.me/uzaidev';
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}
