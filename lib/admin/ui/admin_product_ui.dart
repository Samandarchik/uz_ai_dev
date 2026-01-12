import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/ui/admin_add_product_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_edit_product_ui.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

class AdminProductUi extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const AdminProductUi({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<AdminProductUi> createState() => _AdminProductUiState();
}

class _AdminProductUiState extends State<AdminProductUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Faqat filter qilamiz, yuklamaymiz
      _filterProducts();
    });
  }

  void _filterProducts() {
    final productProvider = context.read<ProductProviderAdmin>();
    productProvider.filterByCategory(widget.categoryId);
  }

  Future<void> _refreshProducts() async {
    final productProvider = context.read<ProductProviderAdmin>();
    await productProvider.initializeProducts(forceRefresh: true);
    _filterProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddProductPage(),
                ),
              );
              
              if (result == true) {
                _refreshProducts();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProducts,
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: Consumer<ProductProviderAdmin>(
        builder: (context, productProvider, child) {
          // Loading holati
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          // Bo'sh holat
          if (productProvider.filteredProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu kategoriyada mahsulotlar yo\'q',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshProducts,
            child: ListView.separated(
              separatorBuilder: (context, index) => const Divider(),
              padding: const EdgeInsets.all(8),
              itemCount: productProvider.filteredProducts.length,
              itemBuilder: (context, index) {
                final product = productProvider.filteredProducts[index];
                return _buildProductListTile(context, product);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductListTile(
      BuildContext context, ProductModelAdmin product) {
    return ListTile(
      leading: ClipOval(
        child: GestureDetector(
          onTap: () {
            if (product.imageUrl != null) {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: CachedNetworkImage(
                    imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, size: 40, color: Colors.white),
                  ),
                ),
              );
            }
          },
          child: product.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
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
        '${product.name} (${product.type})',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProductPage(product: product),
                ),
              );
              
              if (result == true) {
                _refreshProducts();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteConfirmDialog(context, product),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, ProductModelAdmin product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить'),
        content: Text('${product.name} Вы хотите удалить продукт?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await context
                  .read<ProductProviderAdmin>()
                  .deleteProduct(product);

              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Продукт удален')),
                );
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}