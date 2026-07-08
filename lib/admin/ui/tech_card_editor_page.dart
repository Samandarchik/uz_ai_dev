import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/services/tech_image_upload_service.dart';
import 'package:uz_ai_dev/admin/ui/composition_picker_page.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_card_section.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_item_editor.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

// Mahsulot tex kartasini (тех карта) Excel «тех карта» varag'iga 1:1 o'xshash
// ko'rinishda tahrirlash sahifasi. Ro'yxatda double-tap orqali ochiladi.
// Saqlanganda mahsulot update qilinadi (faqat tech_card o'zgaradi).
//
// Excel tartibi: mahsulot rasmi → sarlavha jadvali (Наименование/Диаметр/Штук
// + umumiy og'irliklar) → rangli sarlavhali baza bloklari → to'q sariq
// «Расходник» bloki. Keng ekranda bloklar 2 ustunda, telefonda 1 ustunda.

// ---- Excel uslubi konstantalar ----

const Color _kBorderColor = Color(0xFF333333);
const BorderSide _kSide = BorderSide(color: _kBorderColor, width: 1);
const Color _kDefaultHeaderColor = Color(0xFFE0E0E0); // rang tanlanmagan blok
const Color _kConsumableColor = Color(0xFFEE822F); // Расходник doim to'q sariq

// Excel fayllaridan olingan blok sarlavha ranglari (birinchi 4 tasi asosiy).
const List<String> _kPaletteHex = [
  '#E54C5E', // qizil
  '#75BD42', // yashil
  '#FFFF00', // sariq
  '#EE822F', // to'q sariq
  '#4874CB', // ko'k
  '#F2BA02', // oltin
  '#30C0B4', // moviy-yashil
  '#92D050', // och yashil
];

Color? _colorFromHex(String hex) {
  final h = hex.replaceAll('#', '').trim();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

// Og'irlik kg da, 3 xona, VERGUL bilan (Excel'dagi umumiy/blok og'irliklari).
String _kgComma(int grams) =>
    (grams / 1000).toStringAsFixed(3).replaceAll('.', ',');

// Ingredient miqdori kg/litrda, 3 xona, NUQTA bilan (Excel katagi: 1.000).
String _kgDot(int amount) => (amount / 1000).toStringAsFixed(3);

// Excel'dagi birlik yorlig'i.
String _excelUnitLabel(String unit) {
  switch (unit) {
    case 'g':
      return 'Кг';
    case 'ml':
      return 'Литр';
    case 'pcs':
      return 'шт';
    case 'm':
      return 'м';
    default:
      return unit;
  }
}

// Excel'dagi miqdor katagi matni.
String _excelAmount(TechItem item) => (item.unit == 'g' || item.unit == 'ml')
    ? _kgDot(item.amount)
    : item.amount.toString();

const TextStyle _kCellStyle = TextStyle(fontSize: 13, color: Colors.black);
const TextStyle _kCellBold = TextStyle(
  fontSize: 13,
  color: Colors.black,
  fontWeight: FontWeight.bold,
);
const EdgeInsets _kCellPad = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

const double _kUnitColW = 52; // «Кг / Литр / шт / м» ustuni
const double _kAmountColW = 68; // miqdor / og'irlik ustuni

class TechCardEditorPage extends StatefulWidget {
  final ProductModelAdmin product;

  const TechCardEditorPage({super.key, required this.product});

  @override
  State<TechCardEditorPage> createState() => _TechCardEditorPageState();
}

class _TechCardEditorPageState extends State<TechCardEditorPage> {
  late final TechCardController _controller;
  final ImagePicker _picker = ImagePicker();
  final TechImageUploadService _uploader = TechImageUploadService();

  bool _saving = false;

  // Hozir rasm yuklanayotgan baza indekslari.
  final Set<int> _uploadingBases = {};

  TechCardController get c => _controller;

  @override
  void initState() {
    super.initState();
    _controller = TechCardController(widget.product.techCard);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---- Saqlash (eski sahifadagi oqim o'zgarmagan) ----

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final updated = widget.product.copyWith(techCard: _controller.build());
    final provider = context.read<ProductProviderAdmin>();
    final ok = await provider.updateProduct(updated);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Тех карта сохранена')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Ошибка сохранения'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---- Yordamchilar ----

  String _fullImageUrl(String url) {
    if (url.isEmpty) return '';
    return url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  // ---- Партия (Штук) va Диаметр tahriri ----

  Future<void> _editBatchQty() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextFieldDialog(
        title: 'Штук (партия)',
        label: 'Nechta donaga',
        initial: c.batchQty.toString(),
        number: true,
      ),
    );
    if (value == null) return;
    final qty = int.tryParse(value) ?? c.batchQty;
    setState(() => c.batchQty = qty < 1 ? 1 : qty);
  }

  Future<void> _editDiameter() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextFieldDialog(
        title: 'Диаметр (см)',
        label: 'Diametr — bo\'sh qoldirsa bo\'ladi',
        initial: c.diameterCm?.toString() ?? '',
        number: true,
        allowEmpty: true,
      ),
    );
    if (value == null) return;
    setState(() {
      c.diameterCm = value.isEmpty ? null : int.tryParse(value);
    });
  }

  // ---- Baza amallari ----

  Future<void> _addBase() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _TextFieldDialog(
        title: 'Новая база',
        label: 'Название базы',
        initial: '',
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => c.bases.add(TechBase(name: name, ingredients: const [])));
  }

  Future<void> _renameBase(int index) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextFieldDialog(
        title: 'Название базы',
        label: 'Название базы',
        initial: c.bases[index].name,
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => c.bases[index] = c.bases[index].copyWith(name: name));
  }

  Future<void> _deleteBase(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('«${c.bases[index].name}» ni o\'chirasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      c.bases.removeAt(index);
      // Yuklanish indekslarini siljitamiz (o'chirilgan indeks tushib qoladi).
      final shifted = _uploadingBases
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toSet();
      _uploadingBases
        ..clear()
        ..addAll(shifted);
    });
  }

  // Blok sarlavhasidagi ⋮ / long-press menyusi.
  Future<void> _showBaseMenu(int index) async {
    final base = c.bases[index];
    final hasImage = base.imageUrl.isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Rangni tanlash'),
              onTap: () {
                Navigator.pop(ctx);
                _pickBaseColor(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(hasImage ? 'Rasmni o\'zgartirish' : 'Rasm qo\'shish'),
              onTap: () {
                Navigator.pop(ctx);
                _pickBaseImage(index);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Rasmni o\'chirish'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() =>
                      c.bases[index] = c.bases[index].copyWith(imageUrl: ''));
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Blokni o\'chirish',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteBase(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Rang tanlash ----

  Future<void> _pickBaseColor(int index) async {
    final hex = await showDialog<String>(
      context: context,
      builder: (_) => _ColorPickerDialog(current: c.bases[index].color),
    );
    if (hex == null) return;
    setState(() => c.bases[index] = c.bases[index].copyWith(color: hex));
  }

  // ---- Baza rasmi: tanlash + yuklash ----

  Future<void> _pickBaseImage(int index) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выбор изображения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Из галереи'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Из камеры'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) _snack('Ошибка выбора изображения: $e', error: true);
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _uploadingBases.add(index));
    final url = await _uploader.upload(File(picked.path));
    if (!mounted) return;
    setState(() {
      _uploadingBases.remove(index);
      // Muvaffaqiyatda yangi URL, xatoda eski URL saqlanadi.
      if (url != null && index < c.bases.length) {
        c.bases[index] = c.bases[index].copyWith(imageUrl: url);
      }
    });
    if (url == null) {
      _snack('Rasm yuklanmadi. Qayta urinib ko\'ring.', error: true);
    }
  }

  // Rasmga tap: ko'rish + o'zgartirish/o'chirish.
  Future<void> _viewBaseImage(int index) async {
    final url = _fullImageUrl(c.bases[index].imageUrl);
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                  errorWidget: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickBaseImage(index);
                  },
                  child: const Text('O\'zgartirish'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => c.bases[index] =
                        c.bases[index].copyWith(imageUrl: ''));
                  },
                  child: const Text(
                    'O\'chirish',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Yopish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Ingredient amallari (mavjud dialog/sahifalar qayta ishlatiladi) ----

  Future<void> _addIngredient(int baseIndex) async {
    final item = await Navigator.push<TechItem>(
      context,
      MaterialPageRoute(builder: (_) => const CompositionPickerPage()),
    );
    if (item == null || !mounted) return;
    setState(() {
      final base = c.bases[baseIndex];
      c.bases[baseIndex] =
          base.copyWith(ingredients: [...base.ingredients, item]);
    });
  }

  Future<void> _editIngredient(int baseIndex, int itemIndex) async {
    final base = c.bases[baseIndex];
    final updated = await showDialog<TechItem>(
      context: context,
      builder: (_) => EditTechItemDialog(item: base.ingredients[itemIndex]),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final list = List<TechItem>.from(base.ingredients);
      list[itemIndex] = updated;
      c.bases[baseIndex] = base.copyWith(ingredients: list);
    });
  }

  Future<void> _deleteIngredient(int baseIndex, int itemIndex) async {
    final base = c.bases[baseIndex];
    if (!await confirmDeleteTechItem(
        context, base.ingredients[itemIndex].name)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      final list = List<TechItem>.from(base.ingredients)..removeAt(itemIndex);
      c.bases[baseIndex] = base.copyWith(ingredients: list);
    });
  }

  // ---- Расходник amallari ----

  Future<void> _addConsumable() async {
    final item = await Navigator.push<TechItem>(
      context,
      MaterialPageRoute(builder: (_) => const CompositionPickerPage()),
    );
    if (item == null || !mounted) return;
    setState(() => c.consumables.add(item));
  }

  Future<void> _editConsumable(int index) async {
    final updated = await showDialog<TechItem>(
      context: context,
      builder: (_) => EditTechItemDialog(item: c.consumables[index]),
    );
    if (updated == null || !mounted) return;
    setState(() => c.consumables[index] = updated);
  }

  Future<void> _deleteConsumable(int index) async {
    if (!await confirmDeleteTechItem(context, c.consumables[index].name)) {
      return;
    }
    if (!mounted) return;
    setState(() => c.consumables.removeAt(index));
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Сохранить',
                  onPressed: _save,
                ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _productPhoto(),
                _headerTables(wide),
                const SizedBox(height: 12),
                _blocksArea(wide),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addBase,
                    icon: const Icon(Icons.add),
                    label: const Text('База'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Mahsulot rasmi (Excel'dagi eng tepadagi foto) ---

  Widget _productPhoto() {
    final url = _fullImageUrl(widget.product.imageUrl ?? '');
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: url,
            height: 180,
            width: 280,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 180,
              width: 280,
              color: Colors.grey[200],
            ),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  // --- Sarlavha jadvallari (chap: nom/diametr/shtuk, o'ng: umumiy og'irlik) ---

  Widget _headerTables(bool wide) {
    final card = c.build();
    final left = _headerLeftTable();
    final right = _headerRightTable(card);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: left),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [left, const SizedBox(height: 8), right],
    );
  }

  Widget _headerLeftTable() {
    final diameter = c.diameterCm;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: _kSide, left: _kSide, right: _kSide),
      ),
      child: Column(
        children: [
          // 1-qator: yorliqlar (qalin)
          _gridRow([
            _flexCell(const Text('Наименование', style: _kCellBold), flex: 5),
            _flexCell(
              const Text('Диаметр',
                  style: _kCellBold, textAlign: TextAlign.center),
              flex: 2,
              leftBorder: true,
            ),
            _flexCell(
              const Text('Штук', style: _kCellBold,
                  textAlign: TextAlign.center),
              flex: 2,
              leftBorder: true,
            ),
          ]),
          // 2-qator: qiymatlar (diametr/shtuk bosilганда tahrirlanadi)
          _gridRow([
            _flexCell(Text(widget.product.name, style: _kCellBold), flex: 5),
            _flexCell(
              InkWell(
                onTap: _editDiameter,
                child: Padding(
                  padding: _kCellPad,
                  child: Text(
                    diameter == null ? '-' : '$diameter см',
                    style: _kCellStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              flex: 2,
              leftBorder: true,
              padded: false,
            ),
            _flexCell(
              InkWell(
                onTap: _editBatchQty,
                child: Padding(
                  padding: _kCellPad,
                  child: Text(
                    '${c.batchQty} шт',
                    style: _kCellStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              flex: 2,
              leftBorder: true,
              padded: false,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _headerRightTable(TechCard card) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: _kSide, left: _kSide, right: _kSide),
      ),
      child: Column(
        children: [
          _gridRow([
            _flexCell(
              Text(
                'Общий вес за ${c.batchQty} штук - '
                '${_kgComma(card.computedBatchWeightG)} кг',
                style: _kCellBold,
              ),
            ),
          ]),
          _gridRow([
            _flexCell(
              Text(
                'Общий вес за 1 штуку - '
                '${_kgComma(card.computedPieceWeightG)} кг',
                style: _kCellBold,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // --- Bloklar maydoni: keng ekranda 2 ustun, telefonda 1 ustun ---

  Widget _blocksArea(bool wide) {
    final blocks = <Widget>[
      for (int i = 0; i < c.bases.length; i++) _baseBlock(i),
      _consumablesBlock(),
    ];

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in blocks)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: b),
        ],
      );
    }

    final leftCol = <Widget>[];
    final rightCol = <Widget>[];
    for (int i = 0; i < blocks.length; i++) {
      (i.isEven ? leftCol : rightCol).add(
        Padding(padding: const EdgeInsets.only(bottom: 12), child: blocks[i]),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftCol)),
        const SizedBox(width: 12),
        Expanded(child: Column(children: rightCol)),
      ],
    );
  }

  // --- Bitta baza bloki (Excel jadvali ko'rinishida) ---

  Widget _baseBlock(int index) {
    final base = c.bases[index];
    final headerColor = _colorFromHex(base.color) ?? _kDefaultHeaderColor;
    final uploading = _uploadingBases.contains(index);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: _kSide, left: _kSide, right: _kSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rangli sarlavha qatori: nom | кг | og'irlik | ⋮
          GestureDetector(
            onLongPress: () => _showBaseMenu(index),
            child: Container(
              decoration: BoxDecoration(
                color: headerColor,
                border: const Border(bottom: _kSide),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _renameBase(index),
                              child: Padding(
                                padding: _kCellPad,
                                child: Text(
                                  '${base.name} ( на ${c.batchQty} тортов )',
                                  style: _kCellBold,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showBaseMenu(index),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.more_vert,
                                size: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: _kUnitColW,
                      alignment: Alignment.center,
                      decoration:
                          const BoxDecoration(border: Border(left: _kSide)),
                      child: const Text('кг', style: _kCellBold),
                    ),
                    Container(
                      width: _kAmountColW,
                      alignment: Alignment.center,
                      decoration:
                          const BoxDecoration(border: Border(left: _kSide)),
                      child: Text(
                        _kgComma(base.computedWeightG),
                        style: _kCellBold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Blok rasmi (bo'lsa) yoki yuklanish holati
          if (uploading)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: _kSide),
              ),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Rasm yuklanmoqda...', style: _kCellStyle),
                ],
              ),
            )
          else if (base.imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _viewBaseImage(index),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: _kSide),
                ),
                height: 180,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: _fullImageUrl(base.imageUrl),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.broken_image, color: Colors.grey[400]),
                  ),
                ),
              ),
            ),

          // Ingredient qatorlari
          for (int j = 0; j < base.ingredients.length; j++)
            _itemRow(
              base.ingredients[j],
              onTap: () => _editIngredient(index, j),
              onLongPress: () => _deleteIngredient(index, j),
            ),

          // «+ Ингредиент» qatori
          _addRow('+ Ингредиент', () => _addIngredient(index)),
        ],
      ),
    );
  }

  // --- Расходник bloki (sarlavha DOIM to'q sariq #EE822F) ---

  Widget _consumablesBlock() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: _kSide, left: _kSide, right: _kSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: _kConsumableColor,
              border: Border(bottom: _kSide),
            ),
            padding: _kCellPad,
            child: Text(
              'Расходник ( на ${c.batchQty} тортов )',
              style: _kCellBold,
            ),
          ),
          for (int i = 0; i < c.consumables.length; i++)
            _itemRow(
              c.consumables[i],
              onTap: () => _editConsumable(i),
              onLongPress: () => _deleteConsumable(i),
            ),
          _addRow('+ Расходник', _addConsumable),
        ],
      ),
    );
  }

  // --- Umumiy qator/katak yordamchilari (Excel to'ri) ---

  // Bir blokdagi ingredient qatori: nom | birlik | miqdor.
  Widget _itemRow(
    TechItem item, {
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: _kSide),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: _kCellPad,
                  child: Text(item.name, style: _kCellStyle),
                ),
              ),
              Container(
                width: _kUnitColW,
                alignment: Alignment.center,
                decoration: const BoxDecoration(border: Border(left: _kSide)),
                child: Text(_excelUnitLabel(item.unit), style: _kCellStyle),
              ),
              Container(
                width: _kAmountColW,
                alignment: Alignment.center,
                decoration: const BoxDecoration(border: Border(left: _kSide)),
                child: Text(_excelAmount(item), style: _kCellStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Blok oxiridagi nozik «+ ...» qatori.
  Widget _addRow(String label, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: _kSide),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: _kCellPad,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  // Pastki chegarali qator (sarlavha jadvallari uchun).
  Widget _gridRow(List<Widget> cells) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: _kSide)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      ),
    );
  }

  // Egiluvchan katak; leftBorder=true bo'lsa chapdan chiziq chizadi.
  Widget _flexCell(
    Widget child, {
    int flex = 1,
    bool leftBorder = false,
    bool padded = true,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: leftBorder
            ? const BoxDecoration(border: Border(left: _kSide))
            : null,
        child: padded ? Padding(padding: _kCellPad, child: child) : child,
      ),
    );
  }
}

// ---- Rang tanlash dialogi (Excel'dagi to'ldirish ranglari) ----

class _ColorPickerDialog extends StatelessWidget {
  final String current;

  const _ColorPickerDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rangni tanlash'),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          // «Rang yo'q» (standart kulrang sarlavha)
          _swatch(
            context,
            hex: '',
            color: _kDefaultHeaderColor,
            selected: current.isEmpty,
            child: const Icon(Icons.format_color_reset,
                size: 18, color: Colors.black54),
          ),
          for (final hex in _kPaletteHex)
            _swatch(
              context,
              hex: hex,
              color: _colorFromHex(hex)!,
              selected: current.toUpperCase() == hex.toUpperCase(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }

  Widget _swatch(
    BuildContext context, {
    required String hex,
    required Color color,
    required bool selected,
    Widget? child,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, hex),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 20, color: Colors.black)
            : Center(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

// ---- Matn/son kiritish dialogi (nom, diametr, shtuk) ----
// O'z controllerini o'zi yaratadi va dispose qiladi (loyihadagi naqsh).

class _TextFieldDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initial;
  final bool number;
  final bool allowEmpty;

  const _TextFieldDialog({
    required this.title,
    required this.label,
    required this.initial,
    this.number = false,
    this.allowEmpty = false,
  });

  @override
  State<_TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<_TextFieldDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (value.isEmpty && !widget.allowEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: widget.number ? TextInputType.number : null,
        inputFormatters:
            widget.number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
