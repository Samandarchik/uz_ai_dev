import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';
import 'package:uz_ai_dev/user/ui/user_product_detail_ui.dart';

class ProductsScreen extends StatelessWidget {
  final String categoryName;

  const ProductsScreen({super.key, required this.categoryName});

  static const Color _buttonColor = Color(0xFFC5A97B);
  static const Color _bgColor = Color(0xFFFAF6F1);

  String _formatQuantity(double quantity, String? type) {
    if (type != null && type.toLowerCase() == 'шт') {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  void _showQuantityDialog(BuildContext context, ProductModel product) {
    final provider = context.read<ProductProvider>();
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
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final products = provider.getProductsByCategory(categoryName);

          if (products.isEmpty) {
            return Center(child: Text('Mahsulotlar topilmadi'));
          }

          return GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final quantity = provider.getProductQuantity(product.id);
              final isSelected = quantity > 0;

              return GestureDetector(
                onTap: () => context.push(
                  UserProductDetailUi(productId: product.id),
                ),
                onLongPress: () => _showQuantityDialog(context, product),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rasm
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl:
                                "${AppUrls.baseUrl}${product.imageUrl}",
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _buttonColor,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey, size: 30),
                            ),
                          ),
                        ),
                      ),
                      // Nom
                      Padding(
                        padding: EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Tugma
                      Padding(
                        padding: EdgeInsets.fromLTRB(6, 0, 6, 6),
                        child: SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: isSelected
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: _buttonColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () => provider
                                            .decrementProduct(product.id),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Icon(Icons.remove,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                      Text(
                                        _formatQuantity(
                                            quantity, product.type),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => provider
                                            .incrementProduct(product.id),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Icon(Icons.add,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: () =>
                                      provider.incrementProduct(product.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _buttonColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.zero,
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Qo\'shish',
                                    style: TextStyle(
                                      fontSize: 12,
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
            },
          );
        },
      ),
    );
  }
}
