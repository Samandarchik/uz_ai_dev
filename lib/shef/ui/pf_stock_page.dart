// shef/ui/pf_stock_page.dart — «Полуфабрикат qoldig'i» ekrani (PfStockPage):
// shef skladidagi пф'lar. Tepada qidiruv va KATEGORIYA TAB-BAR'i — ro'yxat
// doim BITTA tanlangan kategoriyani ko'rsatadi (birinchisi bilan ochiladi),
// shuning uchun guruh sarlavhalari yo'q. Qatorlar mahsulotlar ro'yxati
// uslubida (shef_tech_card_page.dart → _ProductTile): kartochkasiz yassi
// ListTile, dumaloq rasm, nom + birlik qavs ichida, ostida izoh; o'ngda
// Bor / Band / Mumkin ustunlari. Qidiruvga matn yozilsa kategoriya
// chegarasidan chiqib, BUTUN ro'yxat bo'ylab qidiriladi.
// Qator bosilsa o'sha пф ning TEX KARTASI ochiladi (TechCardEditorPage,
// canEditPrices: false — narxlar faqat o'qish), bosib turilsa mahsulotning
// O'ZI tahrirlanadi (EditProductPage).
// Tab-bar'da kategoriya boshqaruvi: bir marta bosish — o'tish; BOSIB TURISH —
// barmoq turgan joyda kichik menyu (nomini o'zgartirish / mahsulot qo'shish /
// joyini o'zgartirish / o'chirish); ikki marta bosish — nomini o'zgartirish;
// o'ngdagi «+» — yangi kategoriya. Kategoriya dialoglari shu
// yerda MINIMAL (bitta maydon); rasm/printer admin ekranidagi to'liq
// CategoryDialog'da sozlanadi.
// Manba: GET /api/production/pf-stock → ShefProvider.pfStock.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/category_model.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/provider/upload_image_provider.dart';
import 'package:uz_ai_dev/admin/ui/admin_add_product_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_edit_product_ui.dart';
import 'package:uz_ai_dev/admin/ui/tech_card_editor_page.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/widgets/app_network_image.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';
import 'package:uz_ai_dev/shef/provider/shef_provider.dart';
import 'package:uz_ai_dev/shef/ui/widgets/category_group.dart';

// Shef ekranlarining umumiy ranglari (shef_home_ui / shef_tech_card_page bilan
// bir xil).
const Color _bgColor = Color(0xFFFAF6F1);
const Color _accentColor = Color(0xFFC5A97B);

// Kategoriya kaliti — category_group.dart bilan bir xil qoida: nomi bo'sh
// bo'lsa hammasi bitta «Kategoriyasiz» guruhi (''), aks holda id|nom.
String _catKeyOf(PfStockRow r) {
  final name = r.categoryName.trim();
  return name.isEmpty ? '' : '${r.categoryId}|$name';
}

// Tab-bar'dagi bitta kategoriya: kaliti, backend id'si (o'chirish uchun),
// nomi, пф soni va tugaganlari soni. «Kategoriyasiz» uchun id = 0.
class _PfCategory {
  final String key;
  final int id;
  final String title;
  final int count;
  final int emptyCount;

  const _PfCategory(this.key, this.id, this.title, this.count, this.emptyCount);
}

// Tab-bar kategoriyalari — `allCats` TARTIBIDA («Kategoriyasiz» oxirida).
//
// Tartib ataylab alifbo bo'yicha EMAS: foydalanuvchi tab'larni sudrab qayta
// tartiblay oladi (PUT /api/categories/reorder), alifbo esa uni bekor qilardi.
//
// Ikkita manbadan yig'iladi:
//   - `pf` — qoldiq ro'yxatidagi kategoriyalar (soni bilan);
//   - `allCats` + `products` — mahsuloti UMUMAN yo'q kategoriyalar. Bular
//     ro'yxatda ko'rinmasdi (пф'i yo'q), lekin «+» bilan yangi kategoriya
//     qo'shilganda darhol tab bo'lib chiqishi kerak. Mahsuloti bor, lekin
//     пф'i yo'q kategoriyalar (Выпечка, Торты...) bu ekranga kirmaydi.
//
// Natija chaqiruvchi tomonda keshlanadi — har build'da qayta hisoblanmaydi.
List<_PfCategory> _buildPfCategories(
  List<PfStockRow> pf,
  List<CategoryProductAdmin> allCats,
  List<ProductModelAdmin> products,
) {
  final counts = <String, int>{};
  final empties = <String, int>{};
  final titles = <String, String>{};
  final ids = <String, int>{};
  for (final r in pf) {
    final key = _catKeyOf(r);
    counts[key] = (counts[key] ?? 0) + 1;
    if (r.isEmptyStock) empties[key] = (empties[key] ?? 0) + 1;
    titles[key] = key.isEmpty ? kUncategorizedTitle : r.categoryName.trim();
    ids[key] = key.isEmpty ? 0 : r.categoryId;
  }

  // Mahsuloti bor kategoriyalar — BITTA o'tishda.
  final productCounts = <int, int>{};
  for (final p in products) {
    productCounts[p.categoryId] = (productCounts[p.categoryId] ?? 0) + 1;
  }

  // Asosiy ro'yxat — `allCats` tartibida, lekin BO'SH (hali пф'i yo'q)
  // kategoriyalar OLDINGA chiqariladi: «+» bilan yangi qo'shilgani darhol
  // ko'zga tashlansin. Aks holda u ro'yxat oxiriga tushib, gorizontal
  // tab'lar orasida ekrandan chiqib ketardi.
  final fresh = <_PfCategory>[];
  final filled = <_PfCategory>[];
  final used = <String>{};
  for (final c in allCats) {
    final name = c.name.trim();
    if (name.isEmpty) continue;
    final key = '${c.id}|$name';
    final pfCount = counts[key];
    // Пф'i bor YOKI umuman mahsulotsiz (yangi ochilgan) kategoriyalar.
    if (pfCount == null && (productCounts[c.id] ?? 0) > 0) continue;
    used.add(key);
    final cat = _PfCategory(key, c.id, name, pfCount ?? 0, empties[key] ?? 0);
    (pfCount == null ? fresh : filled).add(cat);
  }
  final result = <_PfCategory>[...fresh, ...filled];

  // `allCats` ga tushmagan, lekin qoldiqda uchraydiganlar (shefga kategoriya
  // ro'yxati kelmagan holat) — tartibsiz qolmasin deb oxiriga qo'shiladi;
  // «Kategoriyasiz» esa eng oxirida.
  final leftovers = counts.keys.where((k) => !used.contains(k)).toList()
    ..sort((a, b) {
      if (a.isEmpty) return b.isEmpty ? 0 : 1;
      if (b.isEmpty) return -1;
      return titles[a]!.toLowerCase().compareTo(titles[b]!.toLowerCase());
    });
  for (final k in leftovers) {
    result
        .add(_PfCategory(k, ids[k]!, titles[k]!, counts[k]!, empties[k] ?? 0));
  }
  return result;
}

class PfStockPage extends StatefulWidget {
  const PfStockPage({super.key});

  @override
  State<PfStockPage> createState() => _PfStockPageState();
}

class _PfStockPageState extends State<PfStockPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Tanlangan kategoriya. null — hali tanlanmagan (ro'yxat kelgach birinchi
  // kategoriya tanlanadi).
  String? _selectedKey;

  // Kategoriyalar keshi: uchala manba (identity) o'zgarmasa qayta
  // hisoblanmaydi.
  List<PfStockRow>? _catsSource;
  List<ProductModelAdmin>? _catsProductsSource;
  // DIQQAT: kategoriyalar uchun `identical()` YARAMAYDI —
  // CategoryProviderAdmin.reorderCategories ro'yxatni JOYIDA o'zgartiradi
  // (removeAt + insert), ya'ni obyekt o'sha-o'sha qoladi. Shuning uchun
  // tartibni ham qamrab oladigan barmoq izi solishtiriladi, aks holda
  // ko'chirishdan keyin tab'lar eski tartibda qolib ketardi.
  String _catsAllFingerprint = '';
  List<_PfCategory> _cats = const [];

  // Sudralayotgan chip indeksi — sudralayotganda uning yonidagi kichik son
  // yashiriladi, qo'yilgach yana ko'rinadi.
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShefProvider>().fetchPfStock();
      // Тех карта qatordan ochilishi uchun mahsulotlar YAGONA manbadan bir
      // marta yuklanadi (admin naqshi) — allaqachon yuklangan bo'lsa jim.
      context.read<ProductProviderAdmin>().initializeProducts();
      // Kategoriyalar — «+» bilan qo'shilgan bo'sh kategoriya ham tab bo'lib
      // ko'rinishi uchun.
      context.read<CategoryProviderAdmin>().getCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Build ichidan chaqiriladi, lekin setState qilmaydi — bu shunchaki kesh.
  void _rebuildCats(
    List<PfStockRow> source,
    List<CategoryProductAdmin> allCats,
    List<ProductModelAdmin> products,
  ) {
    final allFingerprint = allCats.map((c) => c.id).join(',');
    if (identical(_catsSource, source) &&
        _catsAllFingerprint == allFingerprint &&
        identical(_catsProductsSource, products)) {
      return;
    }
    _catsSource = source;
    _catsAllFingerprint = allFingerprint;
    _catsProductsSource = products;
    _cats = _buildPfCategories(source, allCats, products);
    // Tanlangan kategoriya yo'q yoki yangilangan ro'yxatdan yo'qolgan bo'lsa —
    // birinchisiga tushamiz.
    if (_cats.isEmpty) {
      _selectedKey = null;
    } else if (!_cats.any((c) => c.key == _selectedKey)) {
      _selectedKey = _cats.first.key;
    }
  }

  // Qator bosilganda shu пф ning тех картаси ochiladi — NARXSIZ rejim
  // (shef_tech_card_page.dart dagi kabi: retsept ko'rinadi/tahrirlanadi,
  // narx maydonlari faqat o'qiladi). Пф qatorida faqat product_id bor,
  // shuning uchun mahsulot ProductProviderAdmin (yagona manba) dan topiladi.
  void _openTechCard(PfStockRow row) {
    final products = context.read<ProductProviderAdmin>().products;
    ProductModelAdmin? found;
    for (final p in products) {
      if (p.id == row.productId) {
        found = p;
        break;
      }
    }
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mahsulot topilmadi — ro\'yxat hali yuklanmoqda'),
        ),
      );
      return;
    }
    final product = found;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechCardEditorPage(
          product: product,
          canEditPrices: false,
        ),
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
        title: const Text(
          'Полуфабрикат qoldig\'i',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Jami soni — ro'yxat yuklanganda ko'rinadi (qidiruvdan mustaqil).
          Selector<ShefProvider, int>(
            selector: (_, p) => p.pfStock.length,
            builder: (context, total, _) => total == 0
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '$total ta',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Consumer<ShefProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingPfStock && provider.pfStock.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.pfStockError != null && provider.pfStock.isEmpty) {
            return _ErrorView(
              message: provider.pfStockError!,
              onRetry: () => provider.fetchPfStock(),
            );
          }

          final all = provider.pfStock;
          // Bo'sh (mahsulotsiz) kategoriyalar ham tab bo'lib chiqishi uchun —
          // «+» bilan qo'shilgani darhol ko'rinsin.
          _rebuildCats(
            all,
            context.watch<CategoryProviderAdmin>().categories,
            context.watch<ProductProviderAdmin>().products,
          );
          final query = _searchQuery.trim().toLowerCase();
          final searching = query.isNotEmpty;

          // Qidiruvda kategoriya chegarasi olib tashlanadi — пф qaysi
          // kategoriyada ekanini bilmasdan ham topiladi.
          final scoped = searching
              ? all
              : all.where((r) => _catKeyOf(r) == _selectedKey).toList();
          final rows = searching
              ? all.where((r) => r.name.toLowerCase().contains(query)).toList()
              : scoped;
          final emptyCount = scoped.where((r) => r.isEmptyStock).length;

          return Column(
            children: [
              if (all.isNotEmpty) _searchField(),
              // Kategoriya qatori DOIM ko'rinadi (qidiruvdan tashqari) — hatto
              // bitta ham kategoriya bo'lmasa ham, chunki «+» aynan shu yerda:
              // aks holda birinchi kategoriyani ochishning iloji bo'lmasdi.
              // Qidiruvda esa natija butun ro'yxatdan keladi, kategoriya
              // chiplari ma'nosini yo'qotadi.
              if (!searching) _categoryTabBar(),
              if (all.isNotEmpty) ...[
                if (!searching) _summaryLine(scoped.length, emptyCount),
                _columnsHeader(),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchPfStock(),
                  child: rows.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 140),
                            Center(
                              child: Text(
                                all.isEmpty
                                    ? 'Полуфабрикат yo\'q'
                                    : 'Topilmadi',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) => _PfStockTile(
                            row: rows[index],
                            onTap: () => _openTechCard(rows[index]),
                            onLongPress: () => _editProduct(rows[index]),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Полуфабрикат qidirish...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Kategoriya qatori. `TabBar` DAN VOZ KECHILDI: uning ichki InkWell'i
  // uzun bosish/sudrash jestlarini o'ziga tortib, ko'chirish ishlamay qolardi.
  // Endi bu oddiy gorizontal ReorderableListView — jestlar to'liq shu yerda:
  //   - bitta bosish  → kategoriyani tanlash;
  //   - ikki marta    → nomini o'zgartirish;
  //   - BOSIB TURIB SUDRASH → joyini almashtirish (alohida rejim kerak emas);
  //   - o'ngdagi «⋮»  → tanlangan kategoriya menyusi, «+» → yangi kategoriya.
  Widget _categoryTabBar() {
    final cats = _cats;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: cats.length,
                onReorderStart: (i) => setState(() => _draggingIndex = i),
                onReorderEnd: (_) => setState(() => _draggingIndex = null),
                // `onReorderItem` — `onReorder` o'rnini bosuvchi: newIndex
                // olib tashlangan element uchun ALLAQACHON to'g'irlangan.
                onReorderItem: (oldIndex, newIndex) {
                  setState(() => _draggingIndex = null);
                  _moveCategory(oldIndex, newIndex);
                },
                itemBuilder: (context, index) =>
                    _categoryChip(cats[index], index),
              ),
            ),
          ),
          // Tanlangan kategoriya menyusi — tanlanmagan bo'lsa (ro'yxat bo'sh)
          // ko'rsatilmaydi, aks holda hech nima qilmaydigan tugma bo'lardi.
          if (cats.isNotEmpty)
            Builder(
              builder: (btnContext) => IconButton(
                onPressed: () => _showSelectedCategoryMenu(btnContext),
                icon: const Icon(Icons.more_vert, color: Colors.black54),
                tooltip: 'Kategoriya amallari',
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            onPressed: _addCategory,
            icon: const Icon(Icons.add, color: _accentColor),
            tooltip: 'Kategoriya qo\'shish',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // Bitta kategoriya chipi. Sudralayotganda yonidagi kichik son
  // KO'RINMAYDI, qo'yilgach yana chiqadi.
  Widget _categoryChip(_PfCategory cat, int index) {
    final selected = cat.key == _selectedKey;
    final dragging = _draggingIndex == index;
    return ReorderableDelayedDragStartListener(
      key: ValueKey('pf-cat:${cat.key}'),
      index: index,
      child: GestureDetector(
        onTap: () {
          if (cat.key == _selectedKey) return;
          setState(() => _selectedKey = cat.key);
        },
        onDoubleTap: () => _renameCategory(cat),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _accentColor : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cat.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? Colors.brown.shade800 : Colors.black54,
                ),
              ),
              if (!dragging) ...[
                const SizedBox(width: 5),
                Text(
                  '${cat.count}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // «⋮» — tanlangan kategoriya ustidagi amallar menyusi (tugma ostida ochiladi).
  void _showSelectedCategoryMenu(BuildContext buttonContext) {
    final cat = _cats.where((c) => c.key == _selectedKey).firstOrNull;
    if (cat == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(box.size.bottomLeft(Offset.zero));
    _showCategoryMenu(cat, pos);
  }

  // Tab'ni BOSIB TURISH — barmoq turgan joyda kichik menyu. Og'ir
  // CategoryDialog o'rniga shu yerdan: nomini o'zgartirish, kategoriyaga
  // mahsulot qo'shish, kategoriyani o'chirish.
  Future<void> _showCategoryMenu(_PfCategory cat, Offset pos) async {
    if (cat.key.isEmpty) {
      _snack('«$kUncategorizedTitle» — haqiqiy kategoriya emas', Colors.orange);
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        pos & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: 'rename',
          height: 40,
          child: _MenuRow(Icons.edit_outlined, 'Nomini o\'zgartirish'),
        ),
        PopupMenuItem(
          value: 'add',
          height: 40,
          child: _MenuRow(Icons.add_box_outlined, 'Mahsulot qo\'shish'),
        ),
        PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          height: 40,
          child: _MenuRow(Icons.delete_outline, 'O\'chirish', danger: true),
        ),
      ],
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'rename':
        await _renameCategory(cat);
      case 'add':
        await _addProduct();
      case 'delete':
        await _showDeleteCategoryDialog(cat);
    }
  }

  // Ko'chirish rejimida bitta tab boshqa joyga sudraldi. Tab-bar butun
  // kategoriya ro'yxatining BIR QISMI (пф'i borlari), shuning uchun subset
  // indekslari `CategoryProviderAdmin.categories` dagi to'liq indekslarga
  // o'giriladi — backend butun ro'yxatning yangi tartibini kutadi.
  Future<void> _moveCategory(int oldIndex, int newIndex) async {
    final movable = _movableCats();
    if (oldIndex == newIndex ||
        oldIndex >= movable.length ||
        newIndex >= movable.length) {
      return;
    }
    final provider = context.read<CategoryProviderAdmin>();
    final all = provider.categories;
    final fromId = movable[oldIndex].id;
    final toId = movable[newIndex].id;
    final fromFull = all.indexWhere((c) => c.id == fromId);
    final toFull = all.indexWhere((c) => c.id == toId);
    if (fromFull < 0 || toFull < 0) {
      _snack('Kategoriya ro\'yxati hali yuklanmadi', Colors.orange);
      return;
    }

    final ok = await provider.reorderCategories(fromFull, toFull);
    if (!mounted) return;
    if (!ok) _snack('Tartib saqlanmadi', Colors.red);
  }

  // Sudrab ko'chirish mumkin bo'lgan tab'lar: «Kategoriyasiz» haqiqiy
  // kategoriya emas, uning backend'da tartibi yo'q.
  List<_PfCategory> _movableCats() =>
      _cats.where((c) => c.key.isNotEmpty).toList();

  // Nomini o'zgartirish — bitta maydonli kichik dialog. Printer/rasm bu yerda
  // TEGILMAYDI (updateCategory'da null = o'zgarmaydi); ular admin ekranidagi
  // to'liq CategoryDialog'da sozlanadi.
  Future<void> _renameCategory(_PfCategory cat) async {
    CategoryProductAdmin? found;
    for (final c in context.read<CategoryProviderAdmin>().categories) {
      if (c.id == cat.id) {
        found = c;
        break;
      }
    }
    if (found == null) {
      _snack('Kategoriya ro\'yxati hali yuklanmadi', Colors.orange);
      return;
    }
    final category = found;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
        title: 'Kategoriya nomi',
        label: 'Nomi',
        confirmText: 'Saqlash',
        initial: cat.title,
      ),
    );
    if (name == null || name.isEmpty || name == cat.title || !mounted) return;

    final upload = context.read<CategoryProviderAdminUpload>();
    final ok = await upload.updateCategory(category, newName: name);
    if (!mounted) return;
    if (ok) {
      await _refreshCatalog();
      if (!mounted) return;
      _snack('Nomi «$name» ga o\'zgartirildi', Colors.green);
    } else {
      _snack(upload.error ?? 'O\'zgartirilmadi', Colors.red);
    }
  }

  // «+» (tab-bar yonida) va menyudagi «Mahsulot qo'shish» — bitta kichik
  // dialog / sahifa. Kategoriya nomi bilan yangi kategoriya ochish.
  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(
        title: 'Yangi kategoriya',
        label: 'Kategoriya nomi',
        confirmText: 'Qo\'shish',
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final upload = context.read<CategoryProviderAdminUpload>();
    final ok = await upload.createCategory(
      CategoryProductAdmin(id: 0, name: name, imageUrl: null, printerId: 1),
    );
    if (!mounted) return;
    if (ok) {
      await _refreshCatalog();
      if (!mounted) return;
      _snack('«$name» qo\'shildi', Colors.green);
    } else {
      _snack(upload.error ?? 'Kategoriya qo\'shilmadi', Colors.red);
    }
  }

  // Qatorni BOSIB TURISH — mahsulotning O'ZINI tahrirlash (nom, kategoriya,
  // birlik...). Bitta bosish esa тех картани ochadi.
  Future<void> _editProduct(PfStockRow row) async {
    ProductModelAdmin? found;
    for (final p in context.read<ProductProviderAdmin>().products) {
      if (p.id == row.productId) {
        found = p;
        break;
      }
    }
    if (found == null) {
      _snack('Mahsulot topilmadi — ro\'yxat hali yuklanmoqda', Colors.orange);
      return;
    }
    final product = found;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProductPage(product: product)),
    );
    if (!mounted) return;
    await _refreshCatalog();
  }

  // Yangi mahsulot — admin'dagi to'liq forma (kategoriya shu yerda tanlanadi:
  // sahifa oldindan tanlangan kategoriyani qabul qilmaydi).
  Future<void> _addProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductPage()),
    );
    if (!mounted) return;
    await _refreshCatalog();
  }

  // Kategoriya/mahsulot o'zgargach: tab sarlavhalari va qoldiq ro'yxati.
  Future<void> _refreshCatalog() async {
    await context.read<CategoryProviderAdmin>().getCategories();
    if (!mounted) return;
    await context.read<ProductProviderAdmin>().initializeProducts(
          forceRefresh: true,
        );
    if (!mounted) return;
    await context.read<ShefProvider>().fetchPfStock();
  }

  // Tab'ni BOSIB TURISH — o'chirish. Tasdiqlashsiz o'chirmaymiz, chunki
  // bu qaytarilmaydigan amal; ichida пф bo'lsa alohida ogohlantiramiz
  // (backend ham bunday kategoriyani odatda o'chirtirmaydi).
  Future<void> _showDeleteCategoryDialog(_PfCategory cat) async {
    if (cat.key.isEmpty) {
      _snack('«$kUncategorizedTitle» — haqiqiy kategoriya emas', Colors.orange);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategoriyani o\'chirish'),
        content: Text(
          cat.count > 0
              ? '«${cat.title}» ichida ${cat.count} ta полуфабрикат bor. '
                  'O\'chirishga urinilsinmi?'
              : '«${cat.title}» o\'chirilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final upload = context.read<CategoryProviderAdminUpload>();
    final ok = await upload.deleteCategory(
      CategoryProductAdmin(
        id: cat.id,
        name: cat.title,
        imageUrl: null,
        printerId: 1,
      ),
    );
    if (!mounted) return;
    if (ok) {
      // Tanlangan tab o'chgan bo'lsa `_rebuildCats` birinchisiga o'tkazadi.
      if (_selectedKey == cat.key) _selectedKey = null;
      await context.read<CategoryProviderAdmin>().getCategories();
      if (!mounted) return;
      await context.read<ShefProvider>().fetchPfStock();
      if (!mounted) return;
      _snack('«${cat.title}» o\'chirildi', Colors.green);
    } else {
      _snack(upload.error ?? 'O\'chirilmadi', Colors.red);
    }
  }

  void _snack(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  // Qisqa xulosa: «17 ta полуфабрикат • 3 tasi tugagan» (tanlangan kategoriya
  // doirasida).
  Widget _summaryLine(int total, int emptyCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Row(
        children: [
          Text(
            '$total ta полуфабрикат',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (emptyCount > 0) ...[
            Text(
              ' • ',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
            Text(
              '$emptyCount tasi tugagan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Ustun sarlavhalari — o'ng chekkasi _PfStockTile ning contentPadding'i (14)
  // bilan bir xil bo'lishi kerak, aks holda sonlar ustiga tushmaydi.
  Widget _columnsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 14, 4),
      child: Row(
        children: [
          Expanded(child: SizedBox()),
          SizedBox(
            width: _PfStockTile.colWidth,
            child: Text('Bor',
                textAlign: TextAlign.right, style: _PfStockTile.headStyle),
          ),
          SizedBox(
            width: _PfStockTile.colWidth,
            child: Text('Band',
                textAlign: TextAlign.right, style: _PfStockTile.headStyle),
          ),
          SizedBox(
            width: _PfStockTile.colWidthWide,
            child: Text('Mumkin',
                textAlign: TextAlign.right, style: _PfStockTile.headStyle),
          ),
        ],
      ),
    );
  }
}

// Xato ko'rinishi (qayta urinish tugmasi bilan).
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
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
}

// Ro'yxatdagi bitta полуфабрикат qatori — mahsulotlar ro'yxati uslubi
// (shef_tech_card_page.dart → _ProductTile): kartochkasiz yassi ListTile,
// dumaloq rasm, nom + birlik qavs ichida, ostida izoh. Farqi — o'ngda
// Bor / Band / Mumkin ustunlari; qoldig'i tugagani qizil «Mumkin» sonida.
class _PfStockTile extends StatelessWidget {
  final PfStockRow row;
  // Bosilganda тех карта ochiladi (mahsulotlar ro'yxatidagi kabi),
  // bosib turilganda — mahsulotning o'zi tahrirlanadi.
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PfStockTile({
    required this.row,
    required this.onTap,
    required this.onLongPress,
  });

  static const double colWidth = 48;
  static const double colWidthWide = 58;
  static const TextStyle headStyle =
      TextStyle(fontSize: 11, color: Colors.grey);

  // Sonni chiroyli ko'rsatish: butun bo'lsa kasrsiz, aks holda 1 xona.
  static String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static String _fullImageUrl(String url) {
    if (url.isEmpty) return '';
    return url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';
  }

  // «1 partiya = 20 dona • 3 ta mahsulotda ishlatiladi» (bo'sh bo'laklarsiz).
  String get _subtitle {
    final parts = <String>[
      if (row.batchQty > 0) '1 partiya = ${row.batchQty} dona',
      if (row.usedIn > 0) '${row.usedIn} ta mahsulotda ishlatiladi',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final out = row.isEmptyStock;
    final imageUrl = _fullImageUrl(row.imageUrl);
    final subtitle = _subtitle;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      horizontalTitleGap: 10,
      minLeadingWidth: 50,
      visualDensity: VisualDensity.compact,
      leading: ClipOval(
        child: SizedBox(
          width: 50,
          height: 50,
          child: imageUrl.isEmpty
              ? Container(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.cake_outlined, color: Colors.grey.shade400),
                )
              : AppNetworkImage(
                  imageUrl: imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (_) => Container(color: Colors.grey.shade200),
                  errorWidget: (_) => Container(
                    color: Colors.grey.shade200,
                    child:
                        Icon(Icons.broken_image, color: Colors.grey.shade400),
                  ),
                ),
        ),
      ),
      title: Text(
        row.unit.isEmpty ? row.name : '${row.name} (${row.unit})',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _numCell(_fmtNum(row.stock), Colors.black87, FontWeight.w600),
          _numCell(
            _fmtNum(row.reserved),
            row.reserved > 0 ? Colors.orange.shade800 : Colors.grey.shade500,
            FontWeight.w500,
          ),
          _numCell(
            _fmtNum(row.availableClamped),
            out ? Colors.red.shade700 : _accentColor,
            FontWeight.bold,
            width: colWidthWide,
          ),
        ],
      ),
    );
  }

  Widget _numCell(String text, Color color, FontWeight weight,
      {double width = colWidth}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 14.5, color: color, fontWeight: weight),
      ),
    );
  }
}

// Kategoriya menyusidagi bitta qator: ikonka + matn (o'chirish qizil).
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuRow(this.icon, this.label, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red.shade700 : Colors.black87;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13.5, color: color)),
      ],
    );
  }
}

// Bitta matn maydonli kichik dialog (kategoriya nomi: yangi yoki tahrir).
//
// Kontroller ATAYLAB shu widget ichida: uni `showDialog` qaytargach darhol
// dispose qilish mumkin emas — route chiqish animatsiyasi davomida TextField
// hamon unga bog'liq bo'ladi va Flutter «_dependents.isEmpty» assert'i
// tushadi. State.dispose esa route to'liq olib tashlangach chaqiriladi.
class _NameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmText;
  final String initial;

  const _NameDialog({
    required this.title,
    required this.label,
    required this.confirmText,
    this.initial = '',
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor qilish'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
