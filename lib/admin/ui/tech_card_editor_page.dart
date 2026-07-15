import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/model/tech_card_cost.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/services/tech_image_upload_service.dart';
import 'package:uz_ai_dev/admin/ui/composition_picker_page.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_card_section.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_item_editor.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/production/models/latest_price_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart';
import 'package:uz_ai_dev/production/ui/widgets/price_history_sheet.dart';

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
const double _kPriceColW = 68; // «Цена» ustuni (1 kg/l yoki 1 шт/м narxi)
const double _kSumColW = 80; // «Сумма» ustuni (qator tannarxi)

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

  // Oxirgi xarid narxlari (product_id -> narx) — jonli tannarx kataklari.
  Map<int, LatestPrice> _prices = {};
  bool _pricesLoaded = false;

  // «Прибыль» qatoridagi inline maydonlar (% ↔ сум jonli bog'langan).
  final TextEditingController _profitPctCtrl = TextEditingController();
  final TextEditingController _profitSumCtrl = TextEditingController();
  final FocusNode _profitPctFocus = FocusNode();
  final FocusNode _profitSumFocus = FocusNode();

  // «Доп. расходы» qatoridagi inline maydonlar (% ↔ сум, C0 orqali bog'langan).
  final TextEditingController _overheadPctCtrl = TextEditingController();
  final TextEditingController _overheadSumCtrl = TextEditingController();
  final FocusNode _overheadPctFocus = FocusNode();
  final FocusNode _overheadSumFocus = FocusNode();

  TechCardController get c => _controller;

  @override
  void initState() {
    super.initState();
    _controller = TechCardController(widget.product.techCard);
    _loadPrices();
  }

  // Narxlarni yuklash. Xatoda JIM — sahifa narxsiz ham ishlayveradi
  // (tannarx kataklarida «—» ko'rinadi).
  Future<void> _loadPrices() async {
    try {
      final prices = await ProductionService().fetchLatestPrices();
      if (!mounted) return;
      setState(() {
        _prices = prices;
        _pricesLoaded = true;
      });
    } catch (_) {
      // jim
    }
  }

  @override
  void dispose() {
    _profitPctCtrl.dispose();
    _profitSumCtrl.dispose();
    _profitPctFocus.dispose();
    _profitSumFocus.dispose();
    _overheadPctCtrl.dispose();
    _overheadSumCtrl.dispose();
    _overheadPctFocus.dispose();
    _overheadSumFocus.dispose();
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

  // ---- Jonli tannarx hisoblari (oxirgi xarid narxlari asosida) ----
  // Matematika YAGONA joyda — lib/admin/model/tech_card_cost.dart. Bu yerda
  // faqat shu helperlarni joriy prices/wasteFactors bilan chaqiramiz.

  // Tozalash yo'qotishi koeffitsiyentlari (product_id -> factor, faqat !=1).
  // ProductProviderAdmin ro'yxatidan bir marta yig'iladi (backend ham
  // /api/production/cost da xuddi shu koeffitsiyentni qo'llaydi).
  Map<int, double>? _wasteFactorsCache;

  Map<int, double> get _wasteFactors => _wasteFactorsCache ??=
      techWasteFactors(context.read<ProductProviderAdmin>().products);

  // Qator tannarxi (tozalash yo'qotishi bilan).
  // null — narx yo'q (product_id=0 yoki hech narxlanmagan).
  double? _rowCost(TechItem item) => techRowCost(item, _prices, _wasteFactors);

  // Qatorda ko'rsatiladigan «Цена»: g/ml uchun 1 kg/l narxi (x1000),
  // pcs/m uchun o'z birligi narxi.
  double? _rowUnitPrice(TechItem item) => techRowUnitPrice(item, _prices);

  double _baseCost(TechBase base) =>
      techItemsCost(base.ingredients, _prices, _wasteFactors);

  double get _consumablesCost =>
      techItemsCost(c.consumables, _prices, _wasteFactors);

  // Partiya masalliq tannarxi = barcha bazalar + расходник.
  double get _batchCost =>
      c.bases.fold<double>(0, (sum, b) => sum + _baseCost(b)) +
      _consumablesCost;

  // C0 — 1 dona MASALLIQ tannarxi.
  double get _pieceCost => c.batchQty > 0 ? _batchCost / c.batchQty : 0;

  // C — 1 dona TO'LIQ tannarx = C0 + dop. rasxod.
  double get _fullPieceCost =>
      techFullPieceCost(c.overheadMode, c.overheadValue, _pieceCost);

  // Miqdori kiritilgan, lekin narxi yo'q qatorlar soni (ogohlantirish uchun).
  int get _missingPriceCount {
    int n = 0;
    for (final base in c.bases) {
      for (final it in base.ingredients) {
        if (it.amount > 0 && _rowCost(it) == null) n++;
      }
    }
    for (final it in c.consumables) {
      if (it.amount > 0 && _rowCost(it) == null) n++;
    }
    return n;
  }

  // ---- Dop. rasxod (Доп. расходы) ----
  // overheadMode: 'percent' — C0 dan foiz; 'sum' — so'm/dona.

  // Dop. rasxod so'mda (ko'rsatish uchun). null — hisoblab bo'lmaydi.
  double? get _overheadSum {
    if (c.overheadMode == 'sum') return c.overheadValue;
    if (c.overheadMode == 'percent') {
      if (!_pricesLoaded || _pieceCost <= 0) return null;
      return _pieceCost * c.overheadValue / 100;
    }
    return null;
  }

  // Dop. rasxod foizda (C0 ga nisbatan). null — hisoblab bo'lmaydi.
  double? get _overheadPct {
    if (c.overheadMode == 'percent') return c.overheadValue;
    if (c.overheadMode == 'sum') {
      if (!_pricesLoaded || _pieceCost <= 0) return null;
      return c.overheadValue * 100 / _pieceCost;
    }
    return null;
  }

  // ---- Foyda (ustama) va sotuv narxi ----
  // profitMode: 'percent' — profitValue foiz; 'sum' — profitValue so'm/dona.
  // % ↔ сум konvertatsiya endi TO'LIQ tannarx C orqali (C0 emas).

  // 1 dona uchun foyda so'mda. null — hisoblab bo'lmaydi.
  double? get _profitPerPiece {
    if (c.profitMode == 'percent' && !_pricesLoaded) return null;
    return techProfitPerPiece(c.profitMode, c.profitValue, _fullPieceCost);
  }

  // Foyda foizda. null — hisoblab bo'lmaydi.
  double? get _profitPercent {
    if (c.profitMode == 'sum' && !_pricesLoaded) return null;
    return techProfitPercent(c.profitMode, c.profitValue, _fullPieceCost);
  }

  // Tavsiya etiladigan sotish narxi = roundTo1000(C + foyda).
  // null — foyda belgilanmagan yoki C noma'lum/0.
  int? get _suggestedSalePrice {
    if (!_pricesLoaded) return null;
    return techSuggestedSalePrice(c.profitMode, c.profitValue, _fullPieceCost);
  }

  // Foiz ko'rinishi: butun bo'lsa butun, aks holda 1 kasr (50 / 12.5).
  static String _fmtPercent(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  double _parseProfit(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

  // Foiz maydoniga yozildi — rejim 'percent', summa avto hisoblanadi.
  // Bo'sh/0 — foyda belgilanmagan.
  void _onProfitPctChanged(String text) {
    final v = _parseProfit(text);
    setState(() {
      if (text.trim().isEmpty || v <= 0) {
        c.profitMode = '';
        c.profitValue = 0;
      } else {
        c.profitMode = 'percent';
        c.profitValue = v;
      }
    });
  }

  // Summa maydoniga yozildi — rejim 'sum', foiz avto hisoblanadi.
  void _onProfitSumChanged(String text) {
    final v = _parseProfit(text);
    setState(() {
      if (text.trim().isEmpty || v <= 0) {
        c.profitMode = '';
        c.profitValue = 0;
      } else {
        c.profitMode = 'sum';
        c.profitValue = v;
      }
    });
  }

  // «Доп. расходы» maydonlari — «Прибыль» bilan bir xil naqsh.
  void _onOverheadPctChanged(String text) {
    final v = _parseProfit(text);
    setState(() {
      if (text.trim().isEmpty || v <= 0) {
        c.overheadMode = '';
        c.overheadValue = 0;
      } else {
        c.overheadMode = 'percent';
        c.overheadValue = v;
      }
    });
  }

  void _onOverheadSumChanged(String text) {
    final v = _parseProfit(text);
    setState(() {
      if (text.trim().isEmpty || v <= 0) {
        c.overheadMode = '';
        c.overheadValue = 0;
      } else {
        c.overheadMode = 'sum';
        c.overheadValue = v;
      }
    });
  }

  // Fokusda BO'LMAGAN maydonlarni modeldan qayta to'ldiradi: yozilayotgan
  // maydonga tegilmaydi, ikkinchisi (va tannarx o'zgarganda ikkalasi ham)
  // jonli yangilanadi. build oxirida post-frame chaqiriladi.
  void _syncProfitControllers() {
    if (!_profitPctFocus.hasFocus) {
      final pct = _profitPercent;
      final t = (c.profitMode.isEmpty || pct == null) ? '' : _fmtPercent(pct);
      if (_profitPctCtrl.text != t) _profitPctCtrl.text = t;
    }
    if (!_profitSumFocus.hasFocus) {
      final sum = _profitPerPiece;
      final t =
          (c.profitMode.isEmpty || sum == null) ? '' : sum.round().toString();
      if (_profitSumCtrl.text != t) _profitSumCtrl.text = t;
    }
  }

  void _syncOverheadControllers() {
    if (!_overheadPctFocus.hasFocus) {
      final pct = _overheadPct;
      final t = (c.overheadMode.isEmpty || pct == null) ? '' : _fmtPercent(pct);
      if (_overheadPctCtrl.text != t) _overheadPctCtrl.text = t;
    }
    if (!_overheadSumFocus.hasFocus) {
      final sum = _overheadSum;
      final t =
          (c.overheadMode.isEmpty || sum == null) ? '' : sum.round().toString();
      if (_overheadSumCtrl.text != t) _overheadSumCtrl.text = t;
    }
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

  // ---- Bo'limlar (bosqichlar) amallari ----

  // Bazaning ko'rsatiladigan bo'lim raqami (1-based, noto'g'ri qiymat = 1).
  int _stageOfBase(TechBase base) {
    if (base.stage < 1) return 1;
    if (c.stages.isNotEmpty && base.stage > c.stages.length) return 1;
    return base.stage;
  }

  // Diapazondan chiqib ketgan bo'lim raqamlarini 1 ga tushiradi.
  void _clampBaseStages() {
    for (int i = 0; i < c.bases.length; i++) {
      final s = c.bases[i].stage;
      if (s < 1 || (c.stages.isNotEmpty && s > c.stages.length)) {
        c.bases[i] = c.bases[i].copyWith(stage: 1);
      }
    }
  }

  Future<void> _addStage() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _TextFieldDialog(
        title: 'Yangi bo\'lim',
        label: 'Bo\'lim nomi',
        initial: '',
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      c.stages.add(TechStage(name: name));
      _clampBaseStages();
    });
  }

  Future<void> _renameStage(int index) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextFieldDialog(
        title: 'Bo\'lim nomi',
        label: 'Bo\'lim nomi',
        initial: c.stages[index].name,
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => c.stages[index] = TechStage(name: name));
  }

  // Bo'limni chapga (delta=-1) yoki o'ngga (delta=+1) siljitish.
  // Bazalarning stage raqamlari ham mos ravishda almashtiriladi.
  void _moveStage(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= c.stages.length) return;
    setState(() {
      final tmp = c.stages[index];
      c.stages[index] = c.stages[target];
      c.stages[target] = tmp;
      // stage — 1-based: index+1 <-> target+1 almashadi.
      for (int i = 0; i < c.bases.length; i++) {
        final s = c.bases[i].stage;
        if (s == index + 1) {
          c.bases[i] = c.bases[i].copyWith(stage: target + 1);
        } else if (s == target + 1) {
          c.bases[i] = c.bases[i].copyWith(stage: index + 1);
        }
      }
    });
  }

  Future<void> _deleteStage(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bo\'limni o\'chirish'),
        content: Text(
          '«${index + 1}. ${c.stages[index].name}» o\'chirilsinmi?\n'
          'Bu bo\'limdagi bazalar 1-bo\'limga o\'tadi.',
        ),
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
      c.stages.removeAt(index);
      final deleted = index + 1; // o'chirilgan bo'limning 1-based raqami
      for (int i = 0; i < c.bases.length; i++) {
        final s = c.bases[i].stage;
        if (s == deleted) {
          // O'chirilgan bo'limning bazalari 1-bo'limga tushadi.
          c.bases[i] = c.bases[i].copyWith(stage: 1);
        } else if (s > deleted) {
          // Yuqoridagi bo'limlar bittaga suriladi.
          c.bases[i] = c.bases[i].copyWith(stage: s - 1);
        }
      }
      _clampBaseStages();
    });
  }

  // Bo'lim chipida long-press menyusi.
  Future<void> _showStageMenu(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Nomini tahrirlash'),
              onTap: () {
                Navigator.pop(ctx);
                _renameStage(index);
              },
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Chapga siljitish'),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveStage(index, -1);
                },
              ),
            if (index < c.stages.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: const Text('O\'ngga siljitish'),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveStage(index, 1);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'O\'chirish',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteStage(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Baza uchun bo'lim tanlash dialogi (faqat stages bo'sh bo'lmaganda).
  Future<void> _pickBaseStage(int baseIndex) async {
    final current = _stageOfBase(c.bases[baseIndex]);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Bo\'limni tanlash'),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < c.stages.length; i++)
                  RadioListTile<int>(
                    value: i + 1,
                    title: Text('${i + 1}. ${c.stages[i].name}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() =>
        c.bases[baseIndex] = c.bases[baseIndex].copyWith(stage: picked));
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
            if (c.stages.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Bo\'limni tanlash'),
                subtitle: Text(
                  'Hozir: ${_stageOfBase(base)}-bo\'lim',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickBaseStage(index);
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
    // Har rebuild'dan keyin fokussiz profit/dop.rasxod maydonlarini modelga
    // tenglaymiz (miqdor o'zgarsa summa/foiz jonli yangilanadi).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncProfitControllers();
        _syncOverheadControllers();
      }
    });
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          // Tannarx (1 dona / 1 partiya) — GET /api/production/cost.
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Tannarx',
            onPressed: () => showProductionCostSheet(
              context,
              productId: widget.product.id,
              productName: widget.product.name,
            ),
          ),
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
                _stagesRow(),
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
    final missing = _missingPriceCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
              // Jonli tannarx (oxirgi xarid narxlari bo'yicha).
              _gridRow([
                _flexCell(
                  Text(
                    'Себестоимость за ${c.batchQty} штук - '
                    '${_pricesLoaded ? fmtCostMoney(_batchCost) : '—'} сум',
                    style: _kCellBold,
                  ),
                ),
              ]),
              _gridRow([
                _flexCell(
                  Text(
                    'Себестоимость за 1 штуку - '
                    '${_pricesLoaded ? fmtCostMoney(_pieceCost) : '—'} сум',
                    style: _kCellBold,
                  ),
                ),
              ]),
              // Dop. rasxod (qadoq/kommunal ustamasi) — % ↔ сум jonli, C0 orqali.
              _gridRow([
                _flexCell(_overheadRow(), padded: false),
              ]),
              // To'liq tannarx C = C0 + dop. rasxod (1 dona).
              _gridRow([
                _flexCell(
                  Text(
                    'Полная себестоимость за 1 штуку - '
                    '${_pricesLoaded ? fmtCostMoney(_fullPieceCost) : '—'} сум',
                    style: _kCellBold,
                  ),
                ),
              ]),
              // Foyda (ustama) — qatorning o'zida kiritiladi (% ↔ сум jonli, C orqali).
              _gridRow([
                _flexCell(_profitRow(), padded: false),
              ]),
              // Sotish narxi — SAQLANGAN narx; yangi tavsiya faqat admin
              // «Almashtirish» bosganda qabul qilinadi (avto yangilanmaydi).
              _gridRow([
                _flexCell(_salePriceRow(), padded: false),
              ]),
            ],
          ),
        ),
        // Narxi yo'q masalliqlar ogohlantirishi (tannarx to'liq emas).
        if (_pricesLoaded && missing > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$missing ta masalliqda narx yo\'q',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // «Прибыль» qatori: label + ikkita inline maydon (% va сум).
  // Biriga yozilsa ikkinchisi joriy 1 dona TO'LIQ tannarxidan (C) avto
  // hisoblanadi; oxirgi yozilgan maydon profit_mode ni belgilaydi.
  // Bo'sh = belgilanmagan.
  Widget _profitRow() {
    return Padding(
      padding: _kCellPad,
      child: Row(
        children: [
          const Expanded(child: Text('Прибыль', style: _kCellBold)),
          _profitField(
            controller: _profitPctCtrl,
            focusNode: _profitPctFocus,
            width: 56,
            decimal: true,
            onChanged: _onProfitPctChanged,
          ),
          const Text(' %', style: _kCellBold),
          const SizedBox(width: 10),
          _profitField(
            controller: _profitSumCtrl,
            focusNode: _profitSumFocus,
            width: 96,
            decimal: false,
            onChanged: _onProfitSumChanged,
          ),
          const Text(' сум', style: _kCellBold),
        ],
      ),
    );
  }

  // «Доп. расходы» qatori — «Прибыль» bilan bir xil naqsh, lekin % ↔ сум
  // konvertatsiyasi C0 (masalliq tannarxi) orqali.
  Widget _overheadRow() {
    return Padding(
      padding: _kCellPad,
      child: Row(
        children: [
          const Expanded(child: Text('Доп. расходы', style: _kCellBold)),
          _profitField(
            controller: _overheadPctCtrl,
            focusNode: _overheadPctFocus,
            width: 56,
            decimal: true,
            onChanged: _onOverheadPctChanged,
          ),
          const Text(' %', style: _kCellBold),
          const SizedBox(width: 10),
          _profitField(
            controller: _overheadSumCtrl,
            focusNode: _overheadSumFocus,
            width: 96,
            decimal: false,
            onChanged: _onOverheadSumChanged,
          ),
          const Text(' сум', style: _kCellBold),
        ],
      ),
    );
  }

  // «Цена продажи» qatori: SAQLANGAN salePrice ko'rsatiladi (0 — «—»).
  // Tavsiya (suggested) saqlanganidan farq qilsa, yonida to'q sariq
  // «Yangi: X» + «Almashtirish» chiqadi — bosilsa controller.salePrice
  // yangilanadi (✓ saqlashda backend'ga ketadi). Bu admin tasdiq oqimi.
  Widget _salePriceRow() {
    final stored = c.salePrice;
    final suggested = _suggestedSalePrice;
    final showHint = suggested != null && suggested != stored;
    return Padding(
      padding: _kCellPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цена продажи за 1 штуку - '
            '${stored > 0 ? fmtCostMoney(stored) : '—'} сум',
            style: _kCellBold,
          ),
          if (showHint)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    'Yangi: ${fmtCostMoney(suggested)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => c.salePrice = suggested),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade400),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Almashtirish',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _profitField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required double width,
    required bool decimal,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.right,
        style: _kCellBold,
        decoration: InputDecoration(
          isDense: true,
          hintText: '—',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  // --- «Bo'limlar» qatori: raqamlangan chiplar + «+ Bo'lim» ---
  // Tap — nomini tahrirlash; long-press — menyu (tahrir/siljitish/o'chirish).

  Widget _stagesRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Bo\'limlar:', style: _kCellBold),
          if (c.stages.isEmpty)
            Chip(
              label: Text(
                'Bo\'lim qo\'shilmagan (hammasi 1-bo\'lim)',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
              backgroundColor: Colors.grey[100],
              visualDensity: VisualDensity.compact,
            ),
          for (int i = 0; i < c.stages.length; i++)
            GestureDetector(
              onLongPress: () => _showStageMenu(i),
              child: ActionChip(
                label: Text(
                  '${i + 1}. ${c.stages[i].name}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                onPressed: () => _renameStage(i),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Bo\'lim', style: TextStyle(fontSize: 12.5)),
            onPressed: _addStage,
            visualDensity: VisualDensity.compact,
          ),
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
                                  c.stages.isEmpty
                                      ? '${base.name} ( на ${c.batchQty} тортов )'
                                      : '[${_stageOfBase(base)}] ${base.name} '
                                          '( на ${c.batchQty} тортов )',
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
                    // Blok tannarxi (Цена+Сумма ustunlari ustida birlashgan).
                    _moneyCell(
                      _pricesLoaded ? fmtCostMoney(_baseCost(base)) : '—',
                      width: _kPriceColW + _kSumColW,
                      bold: true,
                      grey: !_pricesLoaded,
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: _kCellPad,
                      child: Text(
                        'Расходник ( на ${c.batchQty} тортов )',
                        style: _kCellBold,
                      ),
                    ),
                  ),
                  // Расходник tannarxi (o'ng tomonda, Цена+Сумма kengligida).
                  _moneyCell(
                    _pricesLoaded ? fmtCostMoney(_consumablesCost) : '—',
                    width: _kPriceColW + _kSumColW,
                    bold: true,
                    grey: !_pricesLoaded,
                  ),
                ],
              ),
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

  // Narx 30 kundan eski (yangilanmagan) — Цена katagi sariq bo'ladi.
  static const int _kStalePriceDays = 30;

  bool _isStalePrice(TechItem item) {
    final lastPriced = _prices[item.productId]?.lastPriced;
    if (lastPriced == null) return false;
    return DateTime.now().difference(lastPriced).inDays > _kStalePriceDays;
  }

  // Bir blokdagi ingredient qatori: nom | birlik | miqdor | Цена | Сумма.
  // Butun qator InkWell'i tahrirni ochadi; Цена katagining O'Z InkWell'i bor —
  // bosilsa xarid tarixi sheet'i (ichki tap g'olib, long-press esa faqat
  // tashqi InkWell'da bo'lgani uchun o'chirish ishlayveradi).
  Widget _itemRow(
    TechItem item, {
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final price = _rowUnitPrice(item);
    final cost = _rowCost(item);
    final noPrice = cost == null;
    final stale = !noPrice && _isStalePrice(item);
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
              // Цена: g/ml uchun 1 kg/l narxi, pcs/m uchun 1 birlik narxi.
              // Eski narx (>30 kun) — sariq fon; bosilsa xarid tarixi.
              _moneyCell(
                noPrice ? '—' : fmtCostMoney(price!),
                width: _kPriceColW,
                grey: noPrice,
                bg: stale ? const Color(0xFFFFECB3) : null,
                onTap: item.productId != 0
                    ? () => showPriceHistorySheet(
                          context,
                          productId: item.productId,
                          productName: item.name,
                        )
                    : null,
              ),
              // Сумма: kiritilgan miqdorning tannarxi.
              _moneyCell(
                noPrice ? '—' : fmtCostMoney(cost),
                width: _kSumColW,
                grey: noPrice,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pul katagi (Excel to'ri uslubida): o'ngga tekislangan, uzun sonlar
  // FittedBox bilan kichrayadi. grey=true — narx yo'q («—», kulrang).
  // bg — katak foni (eski narx ogohlantirishi); onTap — katakning o'z tap
  // maydoni (narx tarixi).
  Widget _moneyCell(
    String text, {
    required double width,
    bool bold = false,
    bool grey = false,
    Color? bg,
    VoidCallback? onTap,
  }) {
    final cell = Container(
      width: width,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: _kSide),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: grey ? Colors.grey.shade500 : Colors.black,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
    if (onTap == null) return cell;
    return InkWell(onTap: onTap, child: cell);
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
