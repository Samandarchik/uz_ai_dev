import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:uz_ai_dev/user/ui/user_product_detail_ui.dart';

class UserHomeUi extends StatefulWidget {
  const UserHomeUi({super.key});

  @override
  State<UserHomeUi> createState() => _UserHomeUiState();
}

class _UserHomeUiState extends State<UserHomeUi> {
  TokenStorage tokenStorage = sl<TokenStorage>();
  String name = '';

  static const Color _buttonColor = Color(0xFFC5A97B);
  static const Color _bgColor = Color(0xFFFAF6F1);

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
      context.read<ProductProvider>().fetchCategories();
      context.read<ProductProvider>().fetchProducts();
    });
    getMe();
  }

  String _formatQuantity(double quantity, String? type) {
    if (type != null && type.toLowerCase() == 'шт') {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
            onPressed: () => _showContactDialog(context),
            icon: Icon(Icons.info_outline)),
        title: Text(name,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                final provider = context.read<ProductProvider>();
                showSearch(
                  context: context,
                  delegate: _UserProductSearchDelegate(provider),
                );
              },
              icon: Icon(Icons.search)),
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
            return Center(child: Text('Xatolik: ${provider.errorMessage}'));
          }

          return ListView.builder(
            padding: EdgeInsets.only(bottom: 80),
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              final products =
                  provider.getProductsByCategory(category.name);

              if (products.isEmpty) {
                return SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context.push(ProductsScreen(
                                categoryName: category.name,
                              ));
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: Colors.grey.shade400, width: 1),
                              ),
                            ),
                            child: Row(
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
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        itemCount: products.length,
                        itemBuilder: (context, pIndex) {
                          final product = products[pIndex];
                          final quantity =
                              provider.getProductQuantity(product.id);
                          return _ProductCard(
                            imageUrl:
                                "${AppUrls.baseUrl}${product.imageUrl}",
                            name: product.name,
                            quantity: quantity,
                            quantityText:
                                _formatQuantity(quantity, product.type),
                            type: product.type,
                            buttonColor: _buttonColor,
                            onTap: () =>
                                provider.incrementProduct(product.id),
                            onLongPress: () => context.push(
                              UserProductDetailUi(productId: product.id),
                            ),
                            onAdd: () =>
                                provider.incrementProduct(product.id),
                            onRemove: () =>
                                provider.decrementProduct(product.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.totalSelectedProducts > 0) {
            return FloatingActionButton.extended(
              backgroundColor: _buttonColor,
              onPressed: () async {
                context.push(CartPage());
              },
              icon: Icon(Icons.shopping_basket_outlined, color: Colors.white),
              label: Text(
                provider.totalSelectedProducts % 1 == 0
                    ? provider.totalSelectedProducts.toInt().toString()
                    : provider.totalSelectedProducts.toStringAsFixed(3),
                style: TextStyle(color: Colors.white),
              ),
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

class _ProductCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double quantity;
  final String quantityText;
  final String? type;
  final Color buttonColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.imageUrl,
    required this.name,
    required this.quantity,
    required this.quantityText,
    this.type,
    required this.buttonColor,
    required this.onTap,
    required this.onLongPress,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = quantity > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
      width: 180,
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 180,
              height: 160,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 160,
                color: Colors.grey.shade200,
                child: Center(
                    child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: buttonColor,
                )),
              ),
              errorWidget: (context, url, error) => Container(
                height: 160,
                color: Colors.grey.shade200,
                child: Icon(Icons.image_not_supported,
                    color: Colors.grey, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Text(
              type != null && type!.isNotEmpty ? '$name ($type)' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: isSelected
                  ? Container(
                      decoration: BoxDecoration(
                        color: buttonColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onRemove,
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.only(left: 14),
                                    child: Icon(Icons.remove,
                                        color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onAdd,
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 14),
                                    child: Icon(Icons.add,
                                        color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          IgnorePointer(
                            child: Center(
                              child: Text(
                                type != null ? '$quantityText $type' : quantityText,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      child: Text(
                        'Qo\'shish',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _UserProductSearchDelegate extends SearchDelegate<String> {
  final ProductProvider provider;

  _UserProductSearchDelegate(this.provider)
      : super(searchFieldLabel: 'Mahsulot qidirish...');

  static const Color _buttonColor = Color(0xFFC5A97B);

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

  List<ProductModel> _getAllProducts() {
    final all = <ProductModel>[];
    for (var products in provider.productsByCategory.values) {
      all.addAll(products);
    }
    return all;
  }

  Widget _buildSearchList(BuildContext context) {
    final allProducts = _getAllProducts();
    final results = query.isEmpty
        ? <ProductModel>[]
        : allProducts.where((p) {
            final q = query.toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                (p.category?.toLowerCase().contains(q) ?? false);
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
        final quantity = provider.getProductQuantity(product.id);
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
            product.category ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: quantity > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _buttonColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    quantity % 1 == 0
                        ? quantity.toInt().toString()
                        : quantity.toStringAsFixed(3),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          onTap: () {
            provider.incrementProduct(product.id);
            // Rebuild the search results
            query = query;
          },
          onLongPress: () {
            close(context, '');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProductDetailUi(productId: product.id),
              ),
            );
          },
        );
      },
    );
  }
}
