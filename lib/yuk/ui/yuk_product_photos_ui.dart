import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';
import 'package:uz_ai_dev/yuk/services/yuk_service.dart';

// Yuk keltiruvchi olib kelishi kerak bo'lgan mahsulotlarning suratlari.
// AppBar tugmasidan ochiladi: hozirgi (yuborilmagan) buyurtmalardagi
// mahsulotlar bir joyda, har birining katalog rasmi bilan — bozorda nima
// olishni ko'z bilan taniydi. Rasm /api/ombor/products dan (id -> image_url)
// olinadi; rasmi yo'q mahsulot placeholder bilan ko'rinadi.
class YukProductPhotosUi extends StatefulWidget {
  final List<YukOrder> orders;
  const YukProductPhotosUi({super.key, required this.orders});

  @override
  State<YukProductPhotosUi> createState() => _YukProductPhotosUiState();
}

class _YukProductPhotosUiState extends State<YukProductPhotosUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);

  final YukService _service = YukService();
  // product_id -> katalog rasmi (relativ /static/...).
  Map<int, String> _images = {};
  bool _loading = true;

  // Buyurtmalardagi (o'chirilmagan, rasxod bo'lmagan) mahsulotlar — id bo'yicha
  // birlashtirilib, soni jamlanadi.
  late final List<_PhotoProduct> _products = _collectProducts();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final imgs = await _service.fetchBozorProductImages();
    if (!mounted) return;
    setState(() {
      _images = imgs;
      _loading = false;
    });
  }

  List<_PhotoProduct> _collectProducts() {
    final byKey = <String, _PhotoProduct>{};
    final order = <String>[];
    for (final o in widget.orders) {
      for (final it in o.items) {
        if (it.deleted || it.isRasxod) continue;
        final key = it.productId > 0 ? 'p${it.productId}' : 'n${it.name}';
        final acc = byKey[key];
        if (acc == null) {
          byKey[key] = _PhotoProduct(
            productId: it.productId,
            name: it.name,
            type: it.type ?? '',
            count: it.count,
          );
          order.add(key);
        } else {
          acc.count += it.count;
        }
      }
    }
    return [for (final k in order) byKey[k]!];
  }

  String _fmtCount(num v) {
    final d = v.toDouble();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Mahsulot suratlari',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator.adaptive())
          : _products.isEmpty
              ? const Center(
                  child: Text(
                    'Mahsulotlar yo\'q',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.80,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return _ProductPhotoCard(
                      name: p.name,
                      subtitle:
                          '${_fmtCount(p.count)}${p.type.isNotEmpty ? ' ${p.type}' : ''}',
                      imageUrl: _images[p.productId],
                    );
                  },
                ),
    );
  }
}

// Buyurtmalardan yig'ilgan bitta mahsulot (jamlangan soni bilan).
class _PhotoProduct {
  final int productId;
  final String name;
  final String type;
  num count;
  _PhotoProduct({
    required this.productId,
    required this.name,
    required this.type,
    required this.count,
  });
}

// Bitta mahsulot kartasi: rasm (yoki placeholder) + nom + soni. Rasm bosilsa
// to'liq ekranda (kattalashtirib) ko'riladi.
class _ProductPhotoCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? imageUrl;
  const _ProductPhotoCard({
    required this.name,
    required this.subtitle,
    required this.imageUrl,
  });

  static const Color _accentColor = Color(0xFFC5A97B);

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  void _showFull(BuildContext context) {
    if (!_hasImage) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: '${AppUrls.baseUrl}$imageUrl',
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: _accentColor),
                ),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.error, size: 40, color: Colors.white),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showFull(context),
              child: _hasImage
                  ? CachedNetworkImage(
                      imageUrl: '${AppUrls.baseUrl}$imageUrl',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey, size: 30),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.grey, size: 40),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
