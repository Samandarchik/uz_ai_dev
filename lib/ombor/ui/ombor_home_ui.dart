import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';

// Ombor roli uchun bosh ekran — bozor mahsulotlari ro'yxati.
// Hozircha faqat ro'yxat (savatcha/buyurtma keyingi qadamda).
class OmborHomeUi extends StatefulWidget {
  const OmborHomeUi({super.key});

  @override
  State<OmborHomeUi> createState() => _OmborHomeUiState();
}

class _OmborHomeUiState extends State<OmborHomeUi> {
  final TokenStorage tokenStorage = sl<TokenStorage>();

  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OmborProvider>().fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Ombor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              tokenStorage.removeToken();
              tokenStorage.removeRefreshToken();
              context.push(LoginPage());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Consumer<OmborProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchProducts(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = provider.categories;
          if (categories.isEmpty) {
            return const Center(child: Text('Mahsulotlar topilmadi'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final products = provider.productsByCategory[category] ?? [];
              if (products.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ...products.map((p) => _OmborProductTile(product: p)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _OmborProductTile extends StatelessWidget {
  final OmborProduct product;
  const _OmborProductTile({required this.product});

  static const Color _accentColor = Color(0xFFC5A97B);

  String get _subtitle {
    final parts = <String>[];
    if (product.type != null && product.type!.isNotEmpty) {
      parts.add(product.type!);
    }
    if (product.grams != null) {
      parts.add('${product.grams} g');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        product.imageUrl != null && product.imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _accentColor,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (_subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (product.sourceLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Manba: ${product.sourceLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
