// user/ui/order_ui.dart — Seller savati (buyurtma berish) ekrani: CartPage (ProductProvider).
// Miqdorni kg/l dialogda tahrirlash va savatni yuborish (submitOrder).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  // Miqdorni o'zgartirish dialogi (foydalanuvchi kg/l kiritadi)
  void _showQuantityDialog(BuildContext context, ProductModel product) {
    final provider = context.read<ProductProvider>();
    final controller = TextEditingController(
      text: formatQty(
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
            const Text('Сколько вам нужно?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: product.type == 'шт'
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: 'Количество',
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
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text) ?? 0;
              if (quantity > 0) {
                // UI (kg/l) -> API (butun gramm/ml)
                provider.setProductQuantity(
                  product.id,
                  qtyFromUi(quantity, product.type).toDouble(),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Сохранять'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final selected = provider.selectedProducts.entries.toList();

          if (selected.isEmpty) {
            return const Center(
              child: Text('Корзина пуста'),
            );
          }

          // Savatdagi mahsulotlar
          List<ProductModel> cartProducts = [];
          for (var entry in selected) {
            for (var list in provider.productsByCategory.values) {
              final found = list.firstWhere(
                (p) => p.id == entry.key,
                orElse: () => ProductModel(id: 0, name: ""),
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
                            formatQty(quantity, product.type),
                            style: const TextStyle(fontSize: 16),
                          ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () =>
                              provider.decrementProduct(product.id),
                        ),
                        Text(product.type ?? "null"),
                      ],
                    ),
                    onLongPress: () => _showQuantityDialog(context, product),
                    onTap: () => provider.incrementProduct(product.id),
                  ),
                  const Divider(height: 1),
                ],
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
            child: provider.isSubmitting
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () async {
                      try {
                        final warning = await provider.submitOrder();
                        if (!context.mounted) return;
                        if (warning != null) {
                          // Buyurtma qabul qilindi, lekin chek chiqmadi —
                          // pop'dan keyin ham ko'rinishi uchun messenger'ni oldindan olamiz
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(warning),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 6),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Заказ отправлен ✅")),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        // 'Exception: ' prefiks(lar)ini olib tashlab toza xabar ko'rsatamiz
                        var message = e.toString();
                        while (message.startsWith('Exception: ')) {
                          message = message.substring('Exception: '.length);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      }
                    },
                    child: Text(
                      "Заказ (${provider.totalSelectedProducts % 1 == 0 ? provider.totalSelectedProducts.toInt() : provider.totalSelectedProducts.toStringAsFixed(3)})",
                    ),
                  ),
          );
        },
      ),
    );
  }
}
