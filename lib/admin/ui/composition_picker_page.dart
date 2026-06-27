import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/composition_item.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/api_product_service.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

// Ingredient (tarkib) tanlash sahifasi.
// AppBar'da qidiruv maydoni, pastda barcha mahsulotlar ro'yxati.
// Mahsulot tanlanganda miqdor + birlik so'raydigan dialog ochiladi va
// natija sifatida [CompositionItem] qaytaradi.
class CompositionPickerPage extends StatefulWidget {
  final List<String> units;

  const CompositionPickerPage({super.key, required this.units});

  @override
  State<CompositionPickerPage> createState() => _CompositionPickerPageState();
}

class _CompositionPickerPageState extends State<CompositionPickerPage> {
  final ApiProductService _service = ApiProductService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductModelAdmin> _allProducts = [];
  List<ProductModelAdmin> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _service.getAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _filtered = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allProducts;
      } else {
        _filtered = _allProducts
            .where((p) => p.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  String _fullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';
  }

  Future<void> _onProductTap(ProductModelAdmin product) async {
    final result = await showDialog<CompositionItem>(
      context: context,
      builder: (_) => _AmountUnitDialog(
        product: product,
        units: widget.units,
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Поиск продукта...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('Продукты не найдены'));
    }
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = _filtered[index];
        final imageUrl = _fullImageUrl(product.imageUrl);
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 44,
              height: 44,
              child: imageUrl.isEmpty
                  ? Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image, color: Colors.grey[400]),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey[200]),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.broken_image, color: Colors.grey[400]),
                      ),
                    ),
            ),
          ),
          title: Text(product.name),
          subtitle: product.type.isNotEmpty ? Text(product.type) : null,
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () => _onProductTap(product),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Miqdor (amount) + birlik (unit) kiritish dialogi.
class _AmountUnitDialog extends StatefulWidget {
  final ProductModelAdmin product;
  final List<String> units;

  const _AmountUnitDialog({required this.product, required this.units});

  @override
  State<_AmountUnitDialog> createState() => _AmountUnitDialogState();
}

class _AmountUnitDialogState extends State<_AmountUnitDialog> {
  final TextEditingController _amountController = TextEditingController();
  late String _unit;

  @override
  void initState() {
    super.initState();
    // Default birlik = mahsulot turi (type), agar ro'yxatda bo'lsa.
    if (widget.units.contains(widget.product.type)) {
      _unit = widget.product.type;
    } else {
      _unit = widget.units.isNotEmpty ? widget.units.first : '';
    }
  }

  void _submit() {
    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректное количество')),
      );
      return;
    }
    Navigator.pop(
      context,
      CompositionItem(
        productId: widget.product.id,
        name: widget.product.name,
        amount: amount,
        unit: _unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Количество',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: widget.units.contains(_unit) ? _unit : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ед. изм.',
              border: OutlineInputBorder(),
            ),
            items: widget.units
                .map((u) => DropdownMenuItem<String>(
                      value: u,
                      child: Text(u),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _unit = value ?? _unit;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
