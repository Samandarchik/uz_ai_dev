// Mahsulotlar ekrani
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';

class ProductsScreen extends StatelessWidget {
  final String categoryName;

  const ProductsScreen({Key? key, required this.categoryName})
      : super(key: key);

  void _showQuantityDialog(BuildContext context, ProductModel product) {
    final provider = context.read<ProductProvider>();
    final controller = TextEditingController(
      text: provider.getProductQuantity(product.id).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nechta kerak?'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Miqdor',
                border: OutlineInputBorder(),
                suffixText: product.type,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity > 0) {
                provider.setProductQuantity(product.id, quantity);
              }
              Navigator.pop(context);
            },
            child: Text('Qo\'shish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryName,
        ),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final products = provider.getProductsByCategory(categoryName);

          if (products.isEmpty) {
            return Center(child: Text('Mahsulotlar topilmadi'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final quantity = provider.getProductQuantity(product.id);
              final isSelected = quantity > 0;

              return ListTile(
                selected: isSelected,
                selectedTileColor: Colors.grey.shade300,
                selectedColor: Colors.black,
                leading: ClipOval(
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: CachedNetworkImage(
                            imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) =>
                                Icon(Icons.error, size: 40),
                          ),
                        ),
                      );
                    },
                    child: CachedNetworkImage(
                      imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                      width: 55,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  ),
                ),
                title: Text('${product.name} (${product.type})'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min, // 🔑 MUHIM
                  children: [
                    if (isSelected)
                      Text('$quantity', style: TextStyle(fontSize: 16)),
                    IconButton(
                      icon:
                          Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        provider.decrementProduct(product.id);
                      },
                    ),
                  ],
                ),
                onLongPress: () {
                  _showQuantityDialog(context, product);
                },
                onTap: () => provider.incrementProduct(product.id),
              );
            },
          );
        },
      ),
    );
  }
}
