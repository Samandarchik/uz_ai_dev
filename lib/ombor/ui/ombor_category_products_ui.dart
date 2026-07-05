import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';

// Bitta kategoriya ichidagi bozor mahsulotlari (admin paneldagi kabi:
// kategoriya ro'yxatidan kirib, ichida mahsulotlar ko'rinadi).
class OmborCategoryProductsUi extends StatelessWidget {
  final String categoryName;
  const OmborCategoryProductsUi({super.key, required this.categoryName});

  static const Color _bgColor = Color(0xFFFAF6F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          categoryName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<OmborProvider>(
        builder: (context, provider, child) {
          final products = provider.productsByCategory[categoryName] ?? [];

          if (products.isEmpty) {
            return const Center(child: Text('Mahsulotlar topilmadi'));
          }

          return ListView.builder(
            // Pastdagi savat paneli mahsulotlarni to'smasligi uchun joy.
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: products.length,
            itemBuilder: (context, index) =>
                OmborProductTile(product: products[index]),
          );
        },
      ),
      bottomNavigationBar: const OmborCartBar(),
    );
  }
}

// Pastdagi savat paneli: nechta mahsulot tanlangani + "Buyurtma berish".
class OmborCartBar extends StatelessWidget {
  const OmborCartBar({super.key});

  static const Color _accentColor = Color(0xFFC5A97B);

  Future<void> _submit(BuildContext context, OmborProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await provider.submitOrder();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Buyurtma yuborildi' : message),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OmborProvider>(
      builder: (context, provider, child) {
        if (provider.cartItemCount == 0) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${provider.cartItemCount} ta mahsulot',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Jami: ${formatMilli(provider.cartTotalMilli)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: provider.isSubmitting
                      ? null
                      : () => provider.clearCart(),
                  child: const Text(
                    'Tozalash',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: provider.isSubmitting
                      ? null
                      : () => _submit(context, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: provider.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Buyurtma berish'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OmborProductTile extends StatelessWidget {
  final OmborProduct product;
  const OmborProductTile({super.key, required this.product});

  static const Color _accentColor = Color(0xFFC5A97B);

  String get _subtitle {
    final unit = (product.type != null && product.type!.isNotEmpty)
        ? product.type!
        : '';
    // Ombor (bozor) ekranida pachka miqdori = bozor gramm; bo'lmasa mone gramm.
    final qty = product.bozorGrams ?? product.grams;
    if (qty == null) return unit;

    final v = qty.toDouble();
    final u = unit.toLowerCase();
    final isKg = u == 'kg' || u == 'кг';
    // 1 kg dan kam bo'lsa grammda ko'rsatamiz: 0.4 kg -> "400 gr".
    if (isKg && v > 0 && v < 1) {
      return '${(v * 1000).round()} gr';
    }
    // Ortiqcha nollarsiz: 0.4 -> "0.4", 2 -> "2".
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return unit.isNotEmpty ? '$s $unit' : s;
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
          GestureDetector(
            onTap: () {
              // Rasm bosilsa katta (to'liq) ko'rinishda ochiladi.
              if (!hasImage) return;
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: CachedNetworkImage(
                    imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: _accentColor),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.error,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
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
          const SizedBox(width: 8),
          OmborQtyStepper(
            productId: product.id,
            // Bir qadam = bozor gramm * 1000 (milli-birlik, butun son).
            // 0.4 kg -> 400; bo'lmasa 1 -> 1000.
            stepMilli: ((product.bozorGrams ?? 1) * 1000).round(),
          ),
        ],
      ),
    );
  }
}

// Milli-birlikni (qiymat*1000) faqat butun son arifmetikasi bilan formatlash:
// 1200 -> "1.2", 400 -> "0.4", 2000 -> "2". Float umuman ishlatilmaydi.
String formatMilli(int milli) {
  final whole = milli ~/ 1000;
  final frac = milli % 1000;
  if (frac == 0) return '$whole';
  final f = frac.toString().padLeft(3, '0').replaceAll(RegExp(r'0+$'), '');
  return '$whole.$f';
}

// Mahsulot uchun miqdor tanlash (+/-). Ichkarida milli-birlik (butun son);
// har qadam = stepMilli (bozor gramm * 1000). 0 bo'lsa faqat "+" ko'rinadi.
class OmborQtyStepper extends StatelessWidget {
  final int productId;
  final int stepMilli;
  const OmborQtyStepper(
      {super.key, required this.productId, required this.stepMilli});

  static const Color _accentColor = Color(0xFFC5A97B);

  @override
  Widget build(BuildContext context) {
    return Consumer<OmborProvider>(
      builder: (context, provider, child) {
        final milli = provider.countMilli(productId);

        if (milli <= 0) {
          return _circleButton(
            icon: Icons.add,
            background: _accentColor,
            foreground: Colors.white,
            onTap: () => provider.addToCart(productId, stepMilli),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circleButton(
              icon: Icons.remove,
              background: Colors.grey.shade200,
              foreground: Colors.black87,
              onTap: () => provider.decrement(productId, stepMilli),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                formatMilli(milli),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            _circleButton(
              icon: Icons.add,
              background: _accentColor,
              foreground: Colors.white,
              onTap: () => provider.addToCart(productId, stepMilli),
            ),
          ],
        );
      },
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: foreground),
        ),
      ),
    );
  }
}
