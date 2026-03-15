import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/customer/provider/customer_provider.dart';

class CustomerCartUi extends StatelessWidget {
  const CustomerCartUi({super.key});

  String _formatQuantity(double quantity, String? type) {
    if (type != null && type.toLowerCase() == 'шт') {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  void _showQuantityDialog(
      BuildContext context, CustomerProductModel product) {
    final provider = context.read<CustomerProvider>();
    final controller = TextEditingController(
      text: _formatQuantity(
        provider.getProductQuantity(product.id),
        product.type,
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Qancha kerak?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: product.type == 'шт'
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: 'Miqdor',
                border: const OutlineInputBorder(),
                suffixText: product.type,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text) ?? 0;
              if (quantity > 0) {
                provider.setProductQuantity(product.id, quantity);
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
      appBar: AppBar(title: const Text('Savat')),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          final selected = provider.selectedProducts.entries.toList();

          if (selected.isEmpty) {
            return const Center(child: Text('Savat bo\'sh'));
          }

          // Savatdagi mahsulotlar
          List<CustomerProductModel> cartProducts = [];
          for (var entry in selected) {
            for (var list in provider.productsByCategory.values) {
              final found = list.firstWhere(
                (p) => p.id == entry.key,
                orElse: () => CustomerProductModel(id: 0, name: ""),
              );
              if (found.id != 0) {
                cartProducts.add(found);
                break;
              }
            }
          }

          return ListView.builder(
            itemCount: cartProducts.length,
            itemBuilder: (context, index) {
              final product = cartProducts[index];
              final quantity = provider.getProductQuantity(product.id);

              return Column(
                children: [
                  ListTile(
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
                                imageUrl:
                                    "${AppUrls.baseUrl}${product.imageUrl}",
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (quantity > 0)
                          Text(
                            _formatQuantity(quantity, product.type),
                            style: const TextStyle(fontSize: 16),
                          ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () =>
                              provider.decrementProduct(product.id),
                        ),
                        Text(product.type ?? ""),
                      ],
                    ),
                    onLongPress: () =>
                        _showQuantityDialog(context, product),
                    onTap: () => provider.incrementProduct(product.id),
                  ),
                  const Divider(height: 1),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.selectedProducts.isEmpty) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: provider.isSubmitting
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () async {
                      try {
                        await provider.submitOrder();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Buyurtma yuborildi!")),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Xatolik: $e")),
                        );
                      }
                    },
                    child: Text(
                      "Buyurtma berish (${provider.totalSelectedProducts % 1 == 0 ? provider.totalSelectedProducts.toInt() : provider.totalSelectedProducts.toStringAsFixed(3)})",
                    ),
                  ),
          );
        },
      ),
    );
  }
}
