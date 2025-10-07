import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';

class CartPage extends StatelessWidget {
  const CartPage({Key? key}) : super(key: key);

  void _showQuantityDialog(BuildContext context, int productId) {
    final provider = context.read<ProductProvider>();

    // productni olish
    ProductModel? product;
    for (var list in provider.productsByCategory.values) {
      product = list.firstWhere(
        (p) => p.id == productId,
        orElse: () => ProductModel(id: 0, name: "Noma'lum"),
      );
      if (product.id != 0) break;
    }
    if (product == null || product.id == 0) return;

    final controller = TextEditingController(
      text: provider.getProductQuantity(product.id).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product!.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nechta kerak?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(),
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
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text) ?? 0;
              if (quantity > 0) {
                provider.setProductQuantity(product!.id, quantity);
              }
              Navigator.pop(context);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Savat"),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.selectedProducts.isEmpty) {
            return const Center(
              child: Text("Savat bo‘sh"),
            );
          }

          final selected = provider.selectedProducts.entries.toList();

          return ListView.builder(
            itemCount: selected.length,
            itemBuilder: (context, index) {
              final productId = selected[index].key;
              final quantity = selected[index].value;

              // productni olish
              ProductModel? product;
              for (var list in provider.productsByCategory.values) {
                product = list.firstWhere(
                  (p) => p.id == productId,
                  orElse: () => ProductModel(id: 0, name: "Noma'lum"),
                );
                if (product.id != 0) break;
              }

              if (product == null || product.id == 0) return const SizedBox();

              return ListTile(
                selected: true,
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
                            imageUrl: "${AppUrls.baseUrl}${product!.imageUrl}",
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error, size: 40),
                          ),
                        ),
                      );
                    },
                    child: CachedNetworkImage(
                      imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                      width: 55,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  ),
                ),
                title: Text(product.name),
                subtitle: Text("Miqdor: $quantity"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$quantity', style: const TextStyle(fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () {
                        provider.decrementProduct(productId);
                      },
                    ),
                    Text(product.type ?? "null")
                  ],
                ),
                onLongPress: () => _showQuantityDialog(context, product!.id),
                onTap: () => provider.incrementProduct(product!.id),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.selectedProducts.isEmpty) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () async {
                try {
                  await provider.submitOrder();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Buyurtma yuborildi ✅")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Xatolik: $e")),
                  );
                }
              },
              child: Text(
                  "Buyurtma berish (${provider.totalSelectedProducts} ta)"),
            ),
          );
        },
      ),
    );
  }
}
