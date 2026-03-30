import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';

class UserProductDetailUi extends StatelessWidget {
  final int productId;

  const UserProductDetailUi({super.key, required this.productId});

  static const Color _buttonColor = Color(0xFFC5A97B);
  static const Color _bgColor = Color(0xFFFAF6F1);

  String _formatQuantity(double quantity, String? type) {
    if (type != null && type.toLowerCase() == 'шт') {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  ProductModel? _findProduct(ProductProvider provider) {
    for (var products in provider.productsByCategory.values) {
      for (var p in products) {
        if (p.id == productId) return p;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final product = _findProduct(provider);
          if (product == null) {
            return Center(child: Text('Mahsulot topilmadi'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.width * 0.85,
                pinned: true,
                backgroundColor: _bgColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                    fit: BoxFit.cover,
                    width: double.infinity,
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
                          color: Colors.grey, size: 60),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (product.type != null) ...[
                        SizedBox(height: 6),
                        Text(
                          product.type!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      if (product.ingredients != null &&
                          product.ingredients!.isNotEmpty) ...[
                        SizedBox(height: 20),
                        Text(
                          'Tarkibi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          product.ingredients!,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                      SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final product = _findProduct(provider);
          if (product == null) return SizedBox();

          final quantity = provider.getProductQuantity(product.id);
          final isSelected = quantity > 0;

          return Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: isSelected
                ? Container(
                    decoration: BoxDecoration(
                      color: _buttonColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () =>
                              provider.decrementProduct(product.id),
                          icon:
                              Icon(Icons.remove, color: Colors.white, size: 24),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        Text(
                          _formatQuantity(quantity, product.type),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              provider.incrementProduct(product.id),
                          icon: Icon(Icons.add, color: Colors.white, size: 24),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => provider.incrementProduct(product.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        'Savatga qo\'shish',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
