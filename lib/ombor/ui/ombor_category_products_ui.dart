import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/ombor/models/ombor_product_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';

// Bitta kategoriya ichidagi bozor mahsulotlari — user panelidagi
// ProductsScreen kabi GRID ko'rinishda.
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
        title: Text(categoryName),
      ),
      body: Consumer<OmborProvider>(
        builder: (context, provider, child) {
          final products = provider.productsByCategory[categoryName] ?? [];

          if (products.isEmpty) {
            return const Center(child: Text('Mahsulotlar topilmadi'));
          }

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) =>
                OmborProductCard(product: products[index], isGrid: true),
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
                  onPressed:
                      provider.isSubmitting ? null : () => provider.clearCart(),
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

// User panelidagi mahsulot kartochkasi uslubi: rasm tepada, nomi, pastda
// "Qo'shish" yoki -/+ miqdor tugmasi.
// - kartochka bosilsa: bir qadam qo'shiladi
// - uzoq bosilsa: miqdorni qo'lda kiritish oynasi
// - rasm bosilsa: rasm katta ochiladi
// isGrid=true -> grid katakchasi (rasm cho'ziluvchan), false -> gorizontal
// ro'yxat kartasi (eni 180, rasm balandligi 160).
class OmborProductCard extends StatelessWidget {
  final OmborProduct product;
  final bool isGrid;
  const OmborProductCard({super.key, required this.product, this.isGrid = false});

  static const Color _accentColor = Color(0xFFC5A97B);

  // Bir qadam = kartochkada ko'rsatilgan pachka miqdori * 1000 (milli-birlik,
  // butun son). Subtitle bilan BIR XIL fallback: bozor gramm -> mone gramm ->
  // 1. Masalan 0.5 ko'rsatilgan mahsulotda + har bosilganda +0.5 qo'shiladi.
  int get _stepMilli {
    final qty = product.bozorGrams ?? product.grams;
    if (qty == null || qty <= 0) return 1000;
    return (qty * 1000).round();
  }

  String get _subtitle {
    final unit =
        (product.type != null && product.type!.isNotEmpty) ? product.type! : '';
    // Pachka miqdori = bozor gramm; bo'lmasa mone gramm.
    final qty = product.bozorGrams ?? product.grams;
    String qtyText = '';
    if (qty != null) {
      final v = qty.toDouble();
      final u = unit.toLowerCase();
      final isKg = u == 'kg' || u == 'кг';
      // 1 kg dan kam bo'lsa grammda: 0.4 kg -> "400 gr".
      if (isKg && v > 0 && v < 1) {
        qtyText = '${(v * 1000).round()} gr';
      } else {
        // Ortiqcha nollarsiz: 0.4 -> "0.4", 2 -> "2".
        final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
        qtyText = unit.isNotEmpty ? '$s $unit' : s;
      }
    } else {
      qtyText = unit;
    }
    final source = product.sourceLabel;
    if (qtyText.isNotEmpty && source.isNotEmpty) return '$qtyText • $source';
    return qtyText.isNotEmpty ? qtyText : source;
  }

  // Uzoq bosilganda miqdorni qo'lda kiritish oynasi: xohlagancha buyurtma
  // berish mumkin. "." yoki "," bilan kasr kiritilsa kasr saqlanadi (0.5 -> 0.5).
  Future<void> _showQtyInputDialog(BuildContext context) async {
    final provider = context.read<OmborProvider>();
    final controller = TextEditingController();
    final current = provider.countMilli(product.id);

    void confirm(BuildContext dialogContext) {
      // Vergul ham nuqta kabi qabul qilinadi: "2,5" -> "2.5".
      final raw = controller.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) return;
      final value = double.tryParse(raw);
      if (value == null) return;
      // Kasr saqlanadi: 0.5 -> 500 milli, 2.5 -> 2500 milli.
      Navigator.pop(dialogContext, (value * 1000).round());
    }

    final milli = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Miqdor',
            hintText: current > 0
                ? 'Hozir: ${formatMilli(current)}'
                : 'Miqdorni kiriting',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => confirm(dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Bekor',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => confirm(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    if (milli != null) {
      provider.setCountMilli(product.id, milli);
    }
  }

  // Rasm bosilsa katta (to'liq) ko'rinishda ochiladi.
  void _showImageDialog(BuildContext context) {
    if (product.imageUrl == null || product.imageUrl!.isEmpty) return;
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
  }

  Widget _buildImage() {
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    if (!hasImage) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.inventory_2_outlined,
            color: Colors.grey, size: 40),
      );
    }
    return CachedNetworkImage(
      imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _accentColor,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported,
            color: Colors.grey, size: 30),
      ),
    );
  }

  // Pastki tugma: tanlanmagan -> "Qo'shish"; tanlangan -> [-  miqdor  +].
  Widget _buildButton(BuildContext context, OmborProvider provider) {
    final milli = provider.countMilli(product.id);
    final isSelected = milli > 0;

    if (!isSelected) {
      return ElevatedButton(
        onPressed: () => provider.addToCart(product.id, _stepMilli),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        child: const Text(
          'Qo\'shish',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final type = product.type;
    final qtyText = (type != null && type.isNotEmpty)
        ? '${formatMilli(milli)} $type'
        : formatMilli(milli);

    return Container(
      decoration: BoxDecoration(
        color: _accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => provider.decrement(product.id, _stepMilli),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child:
                        const Icon(Icons.remove, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => provider.addToCart(product.id, _stepMilli),
                  child: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Text(
                qtyText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OmborProvider>(
      builder: (context, provider, child) {
        final image = GestureDetector(
          onTap: () => _showImageDialog(context),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: isGrid
                ? SizedBox(width: double.infinity, child: _buildImage())
                : SizedBox(
                    width: double.infinity, height: 150, child: _buildImage()),
          ),
        );

        return GestureDetector(
          onTap: () => provider.addToCart(product.id, _stepMilli),
          onLongPress: () => _showQtyInputDialog(context),
          child: Container(
            width: isGrid ? null : 180,
            margin: isGrid
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isGrid ? Expanded(child: image) : image,
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (_subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                    child: Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (!isGrid) const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: _buildButton(context, provider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
