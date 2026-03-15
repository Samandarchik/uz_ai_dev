import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/customer/provider/customer_provider.dart';

class CustomerProductsScreen extends StatelessWidget {
  final String categoryName;

  const CustomerProductsScreen({super.key, required this.categoryName});

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
            Text('Qancha kerak?'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: product.type == 'шт'
                  ? TextInputType.number
                  : TextInputType.numberWithOptions(signed: true),
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
            child: Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text) ?? 0;
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
      appBar: AppBar(title: Text(categoryName)),
      body: Consumer<CustomerProvider>(
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

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
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
                              child: Container(
                                decoration:
                                    BoxDecoration(color: Colors.white),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl:
                                          "${AppUrls.baseUrl}${product.imageUrl}",
                                      fit: BoxFit.contain,
                                      errorWidget: (context, url, error) =>
                                          Icon(Icons.error, size: 40),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(product.ingredients ??
                                          ""),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: CachedNetworkImage(
                          imageUrl:
                              "${AppUrls.baseUrl}${product.imageUrl}",
                          width: 55,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error),
                        ),
                      ),
                    ),
                    title: Text(product.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Text(
                            _formatQuantity(quantity, product.type),
                            style: TextStyle(fontSize: 16),
                          ),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () {
                            provider.decrementProduct(product.id);
                          },
                        ),
                        Text(product.type ?? "")
                      ],
                    ),
                    onLongPress: () {
                      _showQuantityDialog(context, product);
                    },
                    onTap: () => provider.incrementProduct(product.id),
                  ),
                  Divider(height: 1),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
