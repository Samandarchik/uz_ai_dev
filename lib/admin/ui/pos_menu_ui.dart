import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/pos_menu_model.dart';
import 'package:uz_ai_dev/admin/services/pos_menu_service.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart'
    show fmtCostMoney;

// POS menyu — Konak POS ko'radigan katalog aynan POS ko'rinishida:
// tepada kategoriya chiplari, pastda tanlangan kategoriya mahsulotlari.
// GET /api/pos-menu?filial_id=N (faqat admin). Filtr client-side.
//
// MUHIM (int kontrakt): sale_price — butun so'm (0 = narx qo'yilmagan),
// limit_qty — saqlanadigan birlikda BUTUN (кг/л -> gr/ml) —
// formatQtyUnit kg/l ga qaytaradi.

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);

class PosMenuUi extends StatefulWidget {
  const PosMenuUi({super.key});

  @override
  State<PosMenuUi> createState() => _PosMenuUiState();
}

class _PosMenuUiState extends State<PosMenuUi> {
  final PosMenuService _service = PosMenuService();

  PosMenuResult? _result;
  bool _loading = true;
  String? _error;

  // Tanlangan kategoriya id'si (null = "Hammasi").
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchPosMenu();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        // Kategoriya o'chib ketgan bo'lsa filtrni "Hammasi"ga qaytarish.
        if (_selectedCategoryId != null &&
            !result.categories.any((c) => c.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filialName = _result?.filialName ?? '';
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'POS menyu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (filialName.isNotEmpty)
              Text(
                filialName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        bottom: _result == null ? null : _categoryChips(_result!),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kAccent,
        child: _body(),
      ),
    );
  }

  // AppBar ostidagi gorizontal skrollanadigan kategoriya chiplari:
  // "Hammasi" + har kategoriya uchun bittadan. Filtr client-side.
  PreferredSizeWidget _categoryChips(PosMenuResult result) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            _chip(label: 'Hammasi', categoryId: null),
            for (final category in result.categories)
              _chip(label: category.name, categoryId: category.id),
          ],
        ),
      ),
    );
  }

  Widget _chip({required String label, required int? categoryId}) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategoryId = categoryId),
        selectedColor: _kAccent.withValues(alpha: 0.25),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? const Color(0xFF8A6F45) : Colors.black87,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? _kAccent : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && _result == null) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    final all = _result?.products ?? const <PosMenuProduct>[];
    final products = _selectedCategoryId == null
        ? all
        : all.where((p) => p.categoryId == _selectedCategoryId).toList();

    if (products.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _selectedCategoryId == null
                  ? 'Menyuda mahsulot yo\'q'
                  : 'Bu kategoriyada mahsulot yo\'q',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) => _productCard(products[index]),
    );
  }

  // Pull-to-refresh xato/bo'sh holatda ham ishlashi uchun skrollanadigan markaz.
  Widget _scrollableCenter({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  // Bitta mahsulot kartasi: rasm + nom + kategoriya, o'ngda narx,
  // limit bo'lsa kichik badge.
  Widget _productCard(PosMenuProduct product) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _thumbnail(product.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.categoryName,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (product.limitQty > 0) ...[
                    const SizedBox(height: 4),
                    _limitBadge(product),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            product.salePrice > 0
                ? Text(
                    '${fmtCostMoney(product.salePrice)} so\'m',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A6F45),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  )
                : Text(
                    'Narx yo\'q',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // 48x48 dumaloq burchakli rasm; URL bo'sh/xato bo'lsa ikonka.
  Widget _thumbnail(String imageUrl) {
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.bakery_dining,
          color: Color(0xFF8A6F45), size: 24),
    );
    if (imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }

  // Avto-buyurtma limiti badge'i (limit_qty saqlanadigan birlikda butun).
  Widget _limitBadge(PosMenuProduct product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Limit: ${formatQtyUnit(product.limitQty, product.unit)}',
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF8A6F45),
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
