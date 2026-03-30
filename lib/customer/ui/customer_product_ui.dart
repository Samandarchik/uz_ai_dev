import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/customer/provider/customer_provider.dart';
import 'package:uz_ai_dev/customer/ui/customer_product_detail_ui.dart';

class CustomerProductsScreen extends StatelessWidget {
  final String categoryName;

  const CustomerProductsScreen({super.key, required this.categoryName});

  static const Color _buttonColor = Color(0xFFC5A97B);
  static const Color _bgColor = Color(0xFFFAF6F1);

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
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonColor,
              foregroundColor: Colors.white,
            ),
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
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(categoryName),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          final products = provider.getProductsByCategory(categoryName);

          if (products.isEmpty) {
            return Center(child: Text('Mahsulotlar topilmadi'));
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final quantity = provider.getProductQuantity(product.id);
              final isSelected = quantity > 0;

              return GestureDetector(
                onTap: () => context.push(
                  CustomerProductDetailUi(productId: product.id),
                ),
                onLongPress: () => _showQuantityDialog(context, product),
                child: Container(
                  margin: EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rasm
                        ClipRRect(
                            borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(16)),
                            child: CachedNetworkImage(
                              imageUrl:
                                  "${AppUrls.baseUrl}${product.imageUrl}",
                              width: 140,
                              height: 150,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 140,
                                height: 150,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _buttonColor,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 140,
                                height: 150,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey, size: 40),
                              ),
                            ),
                        ),
                        // Ma'lumotlar
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (product.ingredients != null &&
                                    product.ingredients!.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    product.ingredients!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                                Spacer(),
                                // Tugma
                                Row(
                                  children: [
                                    Spacer(),
                                    isSelected
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: _buttonColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () => provider
                                                      .decrementProduct(
                                                          product.id),
                                                  icon: Icon(Icons.remove,
                                                      color: Colors.white,
                                                      size: 18),
                                                  constraints: BoxConstraints(
                                                      minWidth: 36,
                                                      minHeight: 36),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                Padding(
                                                  padding: EdgeInsets
                                                      .symmetric(
                                                          horizontal: 4),
                                                  child: Text(
                                                    _formatQuantity(quantity,
                                                        product.type),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => provider
                                                      .incrementProduct(
                                                          product.id),
                                                  icon: Icon(Icons.add,
                                                      color: Colors.white,
                                                      size: 18),
                                                  constraints: BoxConstraints(
                                                      minWidth: 36,
                                                      minHeight: 36),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ],
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => provider
                                                .incrementProduct(
                                                    product.id),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _buttonColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 10),
                                              elevation: 0,
                                            ),
                                            child: Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 22,
                                            ),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
