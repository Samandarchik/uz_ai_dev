import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/services/get_pdf_service.dart';
import 'package:uz_ai_dev/admin/ui/admin_add_product_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_edit_product_ui.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

class AdminProductUi extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const AdminProductUi({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<AdminProductUi> createState() => _AdminProductUiState();
}

class _AdminProductUiState extends State<AdminProductUi> {
  final ApiPdfService pdfService = ApiPdfService();
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0);
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filterProducts();
    });
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final productProvider = context.read<ProductProviderAdmin>();
    productProvider.filterByCategory(widget.categoryId);
  }

  Future<void> _refreshProducts() async {
    final productProvider = context.read<ProductProviderAdmin>();
    await productProvider.initializeProducts(forceRefresh: true);
    _filterProducts();
  }

  Future<void> _downloadAndSharePdf() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);
    _progressNotifier.value = 0;

    print('\n🟢 ========== UI: YUKLASH BOSHLANDI ==========');
    final uiStopwatch = Stopwatch()..start();

    if (!mounted) return;

    // Progress dialog with ValueNotifier
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, progress, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: progress > 0 ? progress / 100 : null,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    progress > 0
                        ? 'Yuklanmoqda: ${progress.toStringAsFixed(0)}%'
                        : 'Tayyorlanmoqda...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (progress > 0) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.grey[200],
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );

    try {
      // Download va Share with progress callback
      await pdfService.downloadAndSharePdf(
        widget.categoryId,
        onProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total * 100);
            _progressNotifier.value = progress;
            print('📊 UI Progress: ${progress.toStringAsFixed(1)}%');
          }
        },
        shareText: '${widget.categoryName} - Mahsulotlar katalogi',
      );

      // Close dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('✓ PDF tayyor!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      uiStopwatch.stop();
      print(
          '⏱ ========== UI: JAMI VAQT: ${uiStopwatch.elapsedMilliseconds}ms ==========\n');
    } catch (e) {
      // Close dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception:', '').trim(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      uiStopwatch.stop();
      print(
          '⏱ ========== UI: XATOLIK VAQTI: ${uiStopwatch.elapsedMilliseconds}ms ==========\n');
    } finally {
      _progressNotifier.value = 0;
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          // Share button with loading indicator
          ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, progress, child) {
              if (_isDownloading && progress > 0) {
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress / 100,
                          strokeWidth: 2,
                          backgroundColor: Colors.grey[300],
                        ),
                      ),
                      Text(
                        '${progress.toInt()}',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }
              return IconButton(
                onPressed: _isDownloading ? null : _downloadAndSharePdf,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                tooltip: 'PDF ulashish',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddProductPage(),
                ),
              );
              if (result == true) _refreshProducts();
            },
          ),
        ],
      ),
      body: Consumer<ProductProviderAdmin>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (productProvider.filteredProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Bu kategoriyada mahsulotlar yo\'q',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshProducts,
            child: ListView.separated(
              separatorBuilder: (context, index) => const Divider(height: 1),
              padding: const EdgeInsets.all(8),
              itemCount: productProvider.filteredProducts.length,
              itemBuilder: (context, index) {
                final product = productProvider.filteredProducts[index];
                return _buildProductListTile(context, product);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductListTile(
      BuildContext context, ProductModelAdmin product) {
    return ListTile(
      onLongPress: () => _showDeleteConfirmDialog(context, product),
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProductPage(product: product),
          ),
        );
        if (result == true) _refreshProducts();
      },
      leading: ClipOval(
        child: product.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: "${AppUrls.baseUrl}${product.imageUrl}",
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.image_not_supported),
              )
            : Container(
                width: 55,
                height: 55,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported),
              ),
      ),
      title: Text(
        '${product.name} (${product.type})',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, ProductModelAdmin product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O\'chirish'),
        content: Text('${product.name} mahsulotini o\'chirmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final success = await context
                  .read<ProductProviderAdmin>()
                  .deleteProduct(product);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mahsulot o\'chirildi')),
                );
                _refreshProducts();
              }
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }
}
