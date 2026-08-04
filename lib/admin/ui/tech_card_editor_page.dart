// admin/ui/tech_card_editor_page.dart — тех карта / полуфабрикат muharriri
// (eng og'ir admin ekrani): TechCardEditorPage — Excel «тех карта» varag'iga
// 1:1 o'xshash baza bloklari + Расходник tahriri, saqlaganda mahsulot update.
// Narxlar SHU YERDA qo'lda kiritiladi: «Цена продажи» qatori tahrirlanadi
// (marja + partiya jami ko'rsatiladi), «Цена» katagi esa masalliqning qo'lda
// xarid narxi sheet'ini ochadi.
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
import 'package:uz_ai_dev/admin/ui/widgets/cutting_scheme.dart';
import 'package:uz_ai_dev/admin/ui/widgets/product_type_radio.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_card_section.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_item_editor.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/utils/money_input.dart';
import 'package:uz_ai_dev/production/models/latest_price_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';
import 'package:uz_ai_dev/production/ui/widgets/cost_sheet.dart';
import 'package:uz_ai_dev/production/ui/widgets/price_history_sheet.dart';

// Mahsulot tex kartasini (тех карта) Excel «тех карта» varag'iga 1:1 o'xshash
// ko'rinishda tahrirlash sahifasi. Ro'yxatda double-tap orqali ochiladi.
// Saqlanganda mahsulot update qilinadi (faqat tech_card o'zgaradi).
//
// Excel tartibi: mahsulot rasmi → sarlavha jadvali (Наименование/Размер/Штук
// + umumiy og'irliklar) → «Kesish sxemasi» diagrammasi (shakl kiritilganda) →
// rangli sarlavhali baza bloklari → to'q sariq «Расходник» bloki.
// Keng ekranda bloklar 2 ustunda, telefonda 1 ustunda.

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

  // «Цена продажи» qatoridagi inline maydon — sotish narxi QO'LDA yoziladi
  // (avval faqat «Almashtirish» tugmasi orqali o'zgarardi).
  final TextEditingController _salePriceCtrl = TextEditingController();
  final FocusNode _salePriceFocus = FocusNode();

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
    _salePriceCtrl.dispose();
    _salePriceFocus.dispose();
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

  // productId -> mahsulot xaritasi (полуфабрикат qatorlarini aniqlash,
  // og'irlik va rekursiv tannarx uchun). Bir marta yig'iladi.
  Map<int, ProductModelAdmin>? _productByIdCache;

  Map<int, ProductModelAdmin> get _productById => _productByIdCache ??=
      techProductsById(context.read<ProductProviderAdmin>().products);

  // Qator полуфабрикат mahsulotga bog'langanmi.
  bool _isPfItem(TechItem item) =>
      _productById[item.productId]?.isSemiFinished == true;

  // Полуфабрикат qatorining birligi O'Z tex kartasidan kelib chiqadi:
  // batch_unit 'g' → гр ('g'), aks holda дона ('pcs'). Boshqa birlikka
  // o'tkazish taqiqlanadi (дона'dagi пф grammga o'tmaydi). null — ruxsat.
  String? _pfUnitBlockedMessage(TechItem item, String unit) {
    final pf = _productById[item.productId];
    if (pf == null || !pf.isSemiFinished) return null;
    final own = pf.techCard?.batchUnit == 'g' ? 'g' : 'pcs';
    if (unit == own) return null;
    return own == 'g'
        ? '«${pf.name}» гр\'da o\'lchanadi'
        : '«${pf.name}» дона\'da o\'lchanadi — birligi o\'z tex kartasida '
            'шт↔гр bilan o\'zgartiriladi';
  }

  // Qator mahsuloti шт-oilasidan bo'lib, effektiv «1 dona og'irligi» (W)
  // noma'lum bo'lsa — 'g' birligiga O'TKAZISH taqiqlanadi (backend g -> dona
  // konvertini qila olmaydi). null — cheklov yo'q.
  String? _gramBlockedMessage(TechItem item) {
    final p = _productById[item.productId];
    if (p == null || normalizeProductType(p.type) != 'шт') return null;
    if (techEffectivePieceWeightG(item.productId, _productById) > 0) {
      return null;
    }
    return p.isSemiFinished
        ? 'Пф tex kartasida og\'irlik yo\'q — grammda kiritib bo\'lmaydi'
        : '«1 шт = X gr» kiritilmagan — avval mahsulot tahririda kiriting';
  }

  // Qator tannarxi (tozalash yo'qotishi bilan; pf qatori — rekursiv).
  // null — narx yo'q (product_id=0 yoki hech narxlanmagan).
  double? _rowCost(TechItem item) =>
      techRowCost(item, _prices, _wasteFactors, products: _productById);

  // Qatorda ko'rsatiladigan «Цена»: g/ml uchun 1 kg/l narxi (x1000),
  // pcs/m uchun o'z birligi narxi; pf uchun 1 dona rekursiv tannarxi.
  double? _rowUnitPrice(TechItem item) => techRowUnitPrice(item, _prices,
      products: _productById, wasteFactors: _wasteFactors);

  double _baseCost(TechBase base) =>
      techItemsCost(base.ingredients, _prices, _wasteFactors,
          products: _productById);

  double get _consumablesCost =>
      techItemsCost(c.consumables, _prices, _wasteFactors,
          products: _productById);

  // Partiya masalliq tannarxi = barcha bazalar + расходник.
  double get _batchCost =>
      c.bases.fold<double>(0, (sum, b) => sum + _baseCost(b)) +
      _consumablesCost;

  // C0 — 1 dona MASALLIQ tannarxi (partiya JAMI donasiga bo'linadi).
  double get _pieceCost => c.batchQty > 0 ? _batchCost / c.totalPieces : 0;

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

  // Pul maydonida raqamlar probel bilan guruhlangan (200 000) — parse
  // qilishdan oldin probellar tashlanadi.
  double _parseProfit(String s) =>
      double.tryParse(s.replaceAll(' ', '').trim().replaceAll(',', '.')) ?? 0;

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
      final t = (c.profitMode.isEmpty || sum == null)
          ? ''
          : formatMoneyInput(sum);
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
      final t = (c.overheadMode.isEmpty || sum == null)
          ? ''
          : formatMoneyInput(sum);
      if (_overheadSumCtrl.text != t) _overheadSumCtrl.text = t;
    }
  }

  // Sotish narxi maydonini modeldan to'ldiradi (fokusda BO'LMAGANDA):
  // «Almashtirish» bosilganda maydonda ham yangi narx ko'rinishi shart.
  void _syncSalePriceController() {
    if (_salePriceFocus.hasFocus) return;
    final t = c.salePrice > 0 ? formatMoneyInput(c.salePrice) : '';
    if (_salePriceCtrl.text != t) _salePriceCtrl.text = t;
  }

  // Sotish narxi qo'lda yozildi — pul BUTUN so'm (kasr yo'q), bo'sh = 0
  // (belgilanmagan). ✓ (Сохранить) bosilganda saqlanadi.
  void _onSalePriceChanged(String text) {
    setState(() => c.salePrice = parseMoney(text));
  }

  // ---- Размер (shakl) tahriri ----
  // (Штук sarlavha jadvalida, Общее количество «Bo'limlar» qatorida JOYIDA
  // tahrirlanadi — _InlineIntCell; eski dialog metodlari olib tashlangan.)

  // Bitta listdan chiqadigan bo'laklar soni (kesish sxemasi shunga chiziladi).
  // Yangi ma'no: Штук (batchQty) — AYNAN bitta list bo'laklari, bo'lish yo'q;
  // partiya JAMI donasi esa batchQty × listQty (c.totalPieces).
  int get _piecesPerList => c.batchQty < 1 ? 1 : c.batchQty;

  // --- Partiya birligi (полуфабрикат uchun шт ↔ гр) ---
  // 'g' rejimi: partiya GRAMMDA o'lchanadi — 1 dona = 1 гр (sklad/tannarx/pf
  // hisoblari шт'da qolaveradi, гр shu kelishuv orqali). Partiya soni qo'lda
  // kiritilmaydi — _syncGramBatch() masalliqlardan avto hisoblaydi.
  bool get _gramMode => c.batchUnit == 'g';
  String get _unitShort => _gramMode ? 'гр' : 'шт'; // katak suffiksi
  String get _unitPlural => _gramMode ? 'гр' : 'штук'; // «за N штук/гр»
  String get _unitOne => _gramMode ? '1 гр' : '1 штуку'; // «за 1 штуку/гр»
  // Blok sarlavhasidagi partiya yorlig'i: «на 20 тортов» / «на 20000 гр».
  String get _batchLabel =>
      _gramMode ? 'на ${c.totalPieces} гр' : 'на ${c.totalPieces} тортов';

  // Гр rejimida partiya soni (chiqim) QO'LDA kiritiladi — masalliqlar
  // og'irligiga tenglanmaydi: pishirishda yo'qotish bo'ladi (1000 гр
  // masalliqdan 900 гр tayyor chiqishi mumkin). Kiritilgan son — bir marta
  // tayyorlaganda chiqadigan гр; «1 гр tannarxi» ham shunga bo'linadi.
  // List bo'linishi гр'da ma'nosiz — doim 1, ya'ni «Грамм» va «Общее
  // количество» kataklari bir xil sonni ko'rsatadi (ikkalasi ham tahrirlanadi).
  void _setGramBatchQty(int qty) {
    setState(() {
      c.batchQty = qty < 1 ? 1 : qty;
      c.listQty = 1;
    });
  }

  // Гр rejimiga o'tishdan oldingi шт partiya soni — orqaga qaytilsa tiklanadi
  // (гр'da list soni 1 ga tushadi, ya'ni listQty yo'qolib ketardi).
  int? _pcsBatchQtyBackup;
  int? _pcsListQtyBackup;

  void _toggleBatchUnit() {
    setState(() {
      if (_gramMode) {
        c.batchUnit = '';
        c.batchQty = _pcsBatchQtyBackup ?? c.batchQty;
        c.listQty = _pcsListQtyBackup ?? 1;
      } else {
        _pcsBatchQtyBackup = c.batchQty;
        _pcsListQtyBackup = c.listQty;
        c.batchUnit = 'g';
        c.listQty = 1; // гр'da list bo'linishi yo'q
      }
    });
  }

  // шт ↔ гр almashtirgich (faqat полуфабрикат tex kartasida ko'rinadi).
  Widget _unitToggle() {
    return InkWell(
      onTap: _toggleBatchUnit,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_unitShort, style: _kCellStyle),
          const Icon(Icons.swap_horiz, size: 14, color: Colors.black45),
        ],
      ),
    );
  }

  // «Размер» katagidagi matn: shaklga qarab diametr yoki eni×uzunlik
  // (balandlik kiritilgan bo'lsa oxiriga qo'shiladi).
  String _sizeLabel() {
    final h = c.heightCm == null ? '' : '×${c.heightCm}';
    if (c.shape == 'round' && c.diameterCm != null) {
      return '⌀ ${c.diameterCm}$h см';
    }
    if (c.shape == 'rect' && c.widthCm != null && c.lengthCm != null) {
      return '${c.widthCm}×${c.lengthCm}$h см';
    }
    return '-';
  }

  // Shakl + o'lcham dialogi: Круг (диаметр) / Прямоугольник (ширина×длина) / «-».
  // Natija doim izchil: rect'da diametr null, round'da eni/uzunlik null.
  Future<void> _editShape() async {
    final res = await showDialog<_ShapeResult>(
      context: context,
      builder: (_) => _ShapeDialog(
        shape: c.shape,
        diameterCm: c.diameterCm,
        widthCm: c.widthCm,
        lengthCm: c.lengthCm,
        heightCm: c.heightCm,
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      c.shape = res.shape;
      c.diameterCm = res.diameterCm;
      c.widthCm = res.widthCm;
      c.lengthCm = res.lengthCm;
      c.heightCm = res.heightCm;
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
    setState(
        () => c.bases[baseIndex] = c.bases[baseIndex].copyWith(stage: picked));
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
                    setState(() =>
                        c.bases[index] = c.bases[index].copyWith(imageUrl: ''));
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
      // Tanlash dialogi mahsulotni yangilagan bo'lishi mumkin
      // («1 шт = X gr» saqlash) — keshlar qayta yig'iladi.
      _productByIdCache = null;
      _wasteFactorsCache = null;
      final base = c.bases[baseIndex];
      c.bases[baseIndex] =
          base.copyWith(ingredients: [...base.ingredients, item]);
    });
  }

  // Pf tanlash ro'yxatidagi izoh: гр rejimidagi pf — bir partiyada necha гр
  // chiqishi; шт rejimida — 1 dona og'irligi. null — ko'rsatiladigan narsa yo'q.
  String? _pfSubtitle(ProductModelAdmin p) {
    final tc = p.techCard;
    if (tc == null) return null;
    if (tc.batchUnit == 'g') return '1 partiya = ${tc.totalPieces} гр';
    final w = techPfPieceWeightG(p.id, _productById);
    return w > 0 ? '1 dona ≈ $w г' : null;
  }

  // ---- Полуфабрикат qatori qo'shish ----
  // ProductProviderAdmin (yagona manba) dagi is_semi_finished mahsulotlardan
  // tanlanadi; qator dona (шт) birligida oddiy ingredient bo'lib saqlanadi.

  // ---- Полуфабрикат tarkibini JOYIDA ochish ----
  // ПФ chipi bosilsa пф ichidagi masalliqlar SHU qator ostida, oddiy
  // ingredient qatorlari ko'rinishida ochiladi (alohida oyna YO'Q). Miqdorlar
  // shu kartada ishlatilgan ulushga ko'paytirilgan holda ko'rsatiladi: пф
  // partiyasi 20 dona bo'lib, bu kartaga 20 dona ketsa — пф retseptining
  // to'liq miqdori; 10 dona ketsa — yarmi.
  // Kalit: qator yo'li ('b0.2', ichma-ich 'b0.2>1.0') — o'sha qator ochiqmi.
  final Set<String> _expandedPf = <String>{};

  void _togglePfRow(String rowKey) {
    setState(() {
      if (!_expandedPf.remove(rowKey)) _expandedPf.add(rowKey);
    });
  }

  // Пф qatorining ULUSHI: qatorda ko'rsatilgan miqdor пф partiyasining necha
  // barobari. 'pcs' — amount / partiya donasi; 'g' — (amount / 1 dona vazni) /
  // partiya donasi (гр rejimidagi пф'da 1 dona = 1 гр). null — hisoblab
  // bo'lmadi (tex karta yo'q, birlik mos emas yoki og'irlik noma'lum).
  double? _pfUsageFactor(TechItem item) {
    final pf = _productById[item.productId];
    final tc = pf?.techCard;
    if (pf == null || tc == null) return null;
    final total = techTotalPieces(tc);
    if (total <= 0) return null;
    double dona;
    if (item.unit == 'pcs') {
      dona = item.amount.toDouble();
    } else if (item.unit == 'g') {
      final w = techEffectivePieceWeightG(pf.id, _productById);
      if (w <= 0) return null;
      dona = item.amount / w;
    } else {
      return null;
    }
    return dona / total;
  }

  // Ko'paytirilgan miqdor matni: g/ml — кг/литр (3 xona), pcs/m — o'z birligi
  // (kasr chiqsa 1 xona bilan).
  String _scaledAmountText(String unit, double amount) {
    if (unit == 'g' || unit == 'ml') return (amount / 1000).toStringAsFixed(3);
    final rounded = amount.roundToDouble();
    return (amount - rounded).abs() < 0.05
        ? rounded.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
  }

  // Пф tarkibi qatorlari (baza sarlavhalari + masalliqlar + расходник).
  // factor — tashqi ulush (ichma-ich пф'da ko'paytirilib boradi).
  List<Widget> _pfChildRows({
    required TechItem item,
    required double factor,
    required int depth,
    required String parentKey,
  }) {
    final tc = _productById[item.productId]?.techCard;
    if (tc == null) return const [];
    final own = _pfUsageFactor(item);
    if (own == null) {
      return [_pfNoteRow('Miqdorni hisoblab bo\'lmadi', depth)];
    }
    final f = factor * own;
    final rows = <Widget>[];
    for (int bi = 0; bi < tc.bases.length; bi++) {
      final base = tc.bases[bi];
      if (tc.bases.length > 1) rows.add(_pfNoteRow(base.name, depth));
      for (int ii = 0; ii < base.ingredients.length; ii++) {
        rows.add(_pfChildRow(
          ing: base.ingredients[ii],
          factor: f,
          depth: depth,
          rowKey: '$parentKey>$bi.$ii',
        ));
      }
    }
    for (int ci = 0; ci < tc.consumables.length; ci++) {
      if (ci == 0) rows.add(_pfNoteRow('Расходник', depth));
      rows.add(_pfChildRow(
        ing: tc.consumables[ci],
        factor: f,
        depth: depth,
        rowKey: '$parentKey>c$ci',
      ));
    }
    return rows;
  }

  // Ochilgan tarkibdagi guruh sarlavhasi (baza nomi / «Расходник»).
  Widget _pfNoteRow(String text, int depth) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(12.0 + 14 * depth, 4, 8, 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: const Border(bottom: _kSide),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      );

  // Пф tarkibidagi bitta masalliq qatori — tahrirlanmaydi, ustunlar asosiy
  // jadval bilan bir xil (birlik | miqdor | Цена | Сумма).
  Widget _pfChildRow({
    required TechItem ing,
    required double factor,
    required int depth,
    required String rowKey,
  }) {
    final nested = _isPfItem(ing) ? _productById[ing.productId] : null;
    final canExpand = nested != null && depth + 1 < kTechPfMaxDepth;
    final expanded = _expandedPf.contains(rowKey);
    final price = _rowUnitPrice(ing);
    final rowCost = _rowCost(ing);
    final cost = rowCost == null ? null : rowCost * factor;
    final subStyle = TextStyle(fontSize: 12, color: Colors.grey.shade800);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: const Border(bottom: _kSide),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.0 + 14 * depth, 6, 8, 6),
                    child: Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(child: Text(ing.name, style: subStyle)),
                        if (canExpand)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _togglePfRow(rowKey),
                            child: _pfChip(withIcon: true, expanded: expanded),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: _kUnitColW,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(border: Border(left: _kSide)),
                  child: Text(_excelUnitLabel(ing.unit), style: subStyle),
                ),
                Container(
                  width: _kAmountColW,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(border: Border(left: _kSide)),
                  child: Text(
                    _scaledAmountText(ing.unit, ing.amount * factor),
                    style: subStyle,
                  ),
                ),
                // Ichki пф masallig'ining «Цена»si ham bosiladi — narxi yo'q
                // masalliqni shu yerdan qo'lda narxlash mumkin.
                _moneyCell(
                  price == null ? '—' : fmtCostMoney(price),
                  width: _kPriceColW,
                  grey: price == null,
                  bg: _isManualPrice(ing) ? const Color(0xFFD6E9FB) : null,
                  tooltip:
                      _isManualPrice(ing) ? 'Qo\'lda kiritilgan narx' : null,
                  onTap:
                      ing.productId != 0 ? () => _openPriceSheet(ing) : null,
                ),
                _moneyCell(
                  cost == null ? '—' : fmtCostMoney(cost),
                  width: _kSumColW,
                  grey: cost == null,
                ),
              ],
            ),
          ),
        ),
        if (canExpand && expanded)
          ..._pfChildRows(
            item: ing,
            factor: factor,
            depth: depth + 1,
            parentKey: rowKey,
          ),
      ],
    );
  }

  // «ПФ» chipi; withIcon=true bo'lsa ochish/yopish strelkasi qo'shiladi.
  Widget _pfChip({bool withIcon = false, bool expanded = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border.all(color: Colors.purple.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ПФ',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700,
            ),
          ),
          if (withIcon)
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 12,
              color: Colors.purple.shade700,
            ),
        ],
      ),
    );
  }

  Future<void> _addPfIngredient(int baseIndex) async {
    final pfProducts = context
        .read<ProductProviderAdmin>()
        .products
        .where((p) => p.isSemiFinished && p.id != widget.product.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (pfProducts.isEmpty) {
      _snack(
        'Полуфабрикат mahsulot yo\'q. Avval mahsulot tahririda '
        '«Полуфабрикат» belgisini yoqing.',
        error: true,
      );
      return;
    }

    final picked = await showModalBottomSheet<ProductModelAdmin>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Полуфабрикат tanlash',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in pfProducts)
                    ListTile(
                      leading: const Icon(Icons.cake_outlined),
                      title: Text(p.name),
                      subtitle: _pfSubtitle(p) == null
                          ? null
                          : Text(
                              _pfSubtitle(p)!,
                              style: const TextStyle(fontSize: 12),
                            ),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    // Miqdor dialogi: «дона» (eski oqim) yoki «грамм» (faqat pf tex kartasida
    // 1 dona og'irligi ma'lum bo'lsa — backend g -> dona konvertini W bilan
    // qiladi). Grammda unit 'g' bo'lib saqlanadi.
    final res = await showDialog<_PfAmountResult>(
      context: context,
      builder: (_) => _PfAmountDialog(
        title: picked.name,
        batchQty: c.totalPieces,
        pieceWeightG: techPfPieceWeightG(picked.id, _productById),
        gramBatch: picked.techCard?.batchUnit == 'g',
      ),
    );
    if (res == null || !mounted) return;
    if (res.amount <= 0) return;

    setState(() {
      final base = c.bases[baseIndex];
      c.bases[baseIndex] = base.copyWith(ingredients: [
        ...base.ingredients,
        TechItem(
          productId: picked.id,
          name: picked.name,
          unit: res.unit,
          amount: res.amount,
        ),
      ]);
    });
  }

  // Qator joyida tahrirlandi (inline miqdor maydoni yoki birlik menyusi).
  void _updateIngredient(int baseIndex, int itemIndex, TechItem updated) {
    setState(() {
      final base = c.bases[baseIndex];
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
    setState(() {
      // Tanlash dialogi mahsulotni yangilagan bo'lishi mumkin
      // («1 шт = X gr» saqlash) — keshlar qayta yig'iladi.
      _productByIdCache = null;
      _wasteFactorsCache = null;
      c.consumables.add(item);
    });
  }

  void _updateConsumable(int index, TechItem updated) {
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
        _syncSalePriceController();
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
                // Rasm + TO'LIQ kesish sxemasi — hammasi eng tepada,
                // jadvaldan oldin. Sxema yo'q bo'lsa (shakl kiritilmagan
                // yoki Штук = 1 — kesish yo'q) faqat mahsulot rasmi chiqadi.
                if (_schemeVisible) _cuttingScheme() else _productPhoto(),
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

  // Partiyadagi JAMI dona o'zgarganda: listQty = jami ÷ Штук (yaxlitlab, min 1).
  // Saqlashda baribir listQty ketadi — JSON kontrakt o'zgarmagan.
  // Sarlavha jadvalidagi va «Bo'limlar» qatoridagi kataklar shu metodni ishlatadi.
  void _setTotalPieces(int total) {
    if (total < 1) return;
    final per = c.batchQty < 1 ? 1 : c.batchQty;
    final lists = (total / per).round();
    setState(() => c.listQty = lists < 1 ? 1 : lists);
  }

  Widget _headerLeftTable() {
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
              const Text('Размер',
                  style: _kCellBold, textAlign: TextAlign.center),
              flex: 2,
              leftBorder: true,
            ),
            _flexCell(
              Text(_gramMode ? 'Грамм' : 'Штук',
                  style: _kCellBold, textAlign: TextAlign.center),
              flex: 2,
              leftBorder: true,
            ),
          ]),
          // 2-qator: qiymatlar. Размер bosilganda dialog; Штук — JOYIDA
          // tahrirlanadi (inline maydon, dialog yo'q).
          _gridRow([
            _flexCell(Text(widget.product.name, style: _kCellBold), flex: 5),
            _flexCell(
              InkWell(
                onTap: _editShape,
                child: Padding(
                  padding: _kCellPad,
                  child: Text(
                    _sizeLabel(),
                    style: _kCellStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              flex: 2,
              leftBorder: true,
              padded: false,
            ),
            // Штук — bitta listdan chiqadigan dona (batchQty). Birlik (шт↔гр)
            // almashtirish tugmasi BITTA — «Bo'limlar» qatoridagi «Общее
            // количество» yonida; bu katak faqat joriy birlikni ko'rsatadi.
            // Гр rejimida bu — bir marta tayyorlashdagi CHIQIM (гр), qo'lda
            // kiritiladi; list bo'linishi yo'q (listQty = 1).
            _flexCell(
              _InlineIntCell(
                value: c.batchQty,
                suffixText: _unitShort,
                onValue: (qty) => _gramMode
                    ? _setGramBatchQty(qty)
                    : setState(() => c.batchQty = qty < 1 ? 1 : qty),
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
              // Og'irliklar полуфабрикат hissasi bilan (backend qoidasi:
              // pf qatori = amount * pf piece_weight_g).
              _gridRow([
                _flexCell(
                  Text(
                    'Общий вес за ${c.totalPieces} $_unitPlural - '
                    '${_kgComma(techBatchWeightG(card, _productById))} кг',
                    style: _kCellBold,
                  ),
                ),
              ]),
              _gridRow([
                _flexCell(
                  Text(
                    'Общий вес за $_unitOne - '
                    '${_kgComma(techPieceWeightG(card, _productById))} кг',
                    style: _kCellBold,
                  ),
                ),
              ]),
              // Jonli tannarx (oxirgi xarid narxlari bo'yicha).
              _gridRow([
                _flexCell(
                  Text(
                    'Себестоимость за ${c.totalPieces} $_unitPlural - '
                    '${_pricesLoaded ? fmtCostMoney(_batchCost) : '—'} сум',
                    style: _kCellBold,
                  ),
                ),
              ]),
              _gridRow([
                _flexCell(
                  Text(
                    'Себестоимость за $_unitOne - '
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
                    'Полная себестоимость за $_unitOne - '
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
          _warnLine('$missing ta masalliqda narx yo\'q'),
      ],
    );
  }

  // Jadval ostidagi to'q sariq ogohlantirish qatori.
  Widget _warnLine(String text) => Padding(
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
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      );

  // --- «Kesish sxemasi» — shakl + partiya (Штук) dan avto diagramma ---
  // Размер yoki Штук o'zgarsa setState orqali jonli qayta chiziladi.
  // Yonida mahsulot rasmi va bir bo'lakning o'lchami/og'irligi chiqadi.

  // Shakl kiritilgan VA bitta list bir necha bo'lakka kesilsa sxema
  // ko'rinadi. Штук = 1 bo'lsa kesish yo'q — 3D chizma chiqmaydi,
  // faqat mahsulot rasmi qoladi. Гр rejimida «bo'lak» tushunchasi yo'q
  // (partiya soni = og'irlik) — sxema chizilmaydi.
  bool get _schemeVisible =>
      !_gramMode &&
      _piecesPerList > 1 &&
      ((c.shape == 'rect' && (c.widthCm ?? 0) > 0 && (c.lengthCm ?? 0) > 0) ||
          (c.shape == 'round' && (c.diameterCm ?? 0) > 0));

  Widget _cuttingScheme() {
    if (!_schemeVisible) return const SizedBox.shrink();
    final url = _fullImageUrl(widget.product.imageUrl ?? '');
    // Sxema BITTA LIST bo'yicha: bitta list batchQty (Штук) bo'lakka kesiladi.
    final pieces = _piecesPerList;
    final sizeText = CuttingSchemeView.pieceSizeText(
      shape: c.shape,
      widthCm: c.widthCm,
      lengthCm: c.lengthCm,
      diameterCm: c.diameterCm,
      pieces: pieces,
    );
    // Bir bo'lak og'irligi (полуфабрикат hissasi bilan, headerdagi kabi).
    final pieceG = techPieceWeightG(c.build(), _productById);
    final weightText = pieceG <= 0
        ? null
        : (pieceG >= 1000 ? '${_kgComma(pieceG)} кг' : '$pieceG г');
    const capStyle = TextStyle(fontSize: 12, color: Colors.black54);
    const valStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Kesish sxemasi', style: _kCellBold),
          const SizedBox(height: 6),
          Center(
            child: LayoutBuilder(
              builder: (context, cons) {
                // 3 ta BIR XIL o'lchamdagi plitka: to'liq 3D, mahsulot rasmi,
                // bitta bo'lak 3D. Keng ekranda yonma-yon, torda o'raladi.
                final maxW = cons.maxWidth;
                final double tileW = maxW >= 3 * 200 + 24
                    ? ((maxW - 24) / 3).clamp(200.0, 250.0)
                    : (maxW - 12).clamp(140.0, 250.0);
                final tileH = tileW * 0.8;
                Widget tile(String caption, Widget child, [Widget? extra]) {
                  return SizedBox(
                    width: tileW,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: tileW, height: tileH, child: child),
                        const SizedBox(height: 4),
                        Text(caption,
                            textAlign: TextAlign.center, style: capStyle),
                        if (extra != null) extra,
                      ],
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    // 1 — mahsulot rasmi (boshida turadi).
                    if (url.isNotEmpty)
                      tile(
                        'Tayyor ko\'rinishi',
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    // 2 — bitta list/tort kesish sxemasi (3D).
                    tile(
                      "To'liq tort",
                      CuttingSchemeView(
                        shape: c.shape,
                        widthCm: c.widthCm,
                        lengthCm: c.lengthCm,
                        diameterCm: c.diameterCm,
                        heightCm: c.heightCm,
                        pieces: pieces,
                      ),
                    ),
                    // 3 — kesilgan bitta bo'lak (3D) + o'lcham/og'irlik.
                    tile(
                      "Bir bo'lak",
                      PieceSchemeView(
                        shape: c.shape,
                        widthCm: c.widthCm,
                        lengthCm: c.lengthCm,
                        diameterCm: c.diameterCm,
                        heightCm: c.heightCm,
                        pieces: pieces,
                      ),
                      Text(
                        [
                          if (sizeText != null) sizeText,
                          if (weightText != null) '~ $weightText',
                        ].join(' • '),
                        textAlign: TextAlign.center,
                        style: valStyle,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Text('Punktir chiziqlar — kesish joylari',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
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

  // «Цена продажи» qatori: sotish narxi QO'LDA yoziladi (inline maydon,
  // BUTUN so'm; bo'sh = belgilanmagan). ✓ bosilganda saqlanadi.
  // Ostida — «tuliq uzi nechpuligi»: marja (C ga nisbatan) va partiya jami
  // («20 штук — 5 000 000 сум»).
  // Tavsiya (suggested) saqlanganidan farq qilsa, ostida to'q sariq
  // «Yangi: X» + «Almashtirish» chiqadi — bosilsa controller.salePrice
  // (va maydon ham) yangilanadi. Bu admin tasdiq oqimi.
  Widget _salePriceRow() {
    final stored = c.salePrice;
    final suggested = _suggestedSalePrice;
    final showHint = suggested != null && suggested != stored;
    // Marja faqat tannarx ma'lum bo'lganda chiqadi.
    final margin = (stored > 0 && _pricesLoaded)
        ? techMarginPercent(stored, _fullPieceCost)
        : null;
    final info = [
      if (margin != null) 'Marja: ${_fmtPercent(margin)}%',
      if (stored > 0)
        '${c.totalPieces} $_unitPlural — '
            '${fmtCostMoney(stored * c.totalPieces)} сум',
    ].join('  •  ');
    return Padding(
      padding: _kCellPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Цена продажи за $_unitOne', style: _kCellBold),
              ),
              _profitField(
                controller: _salePriceCtrl,
                focusNode: _salePriceFocus,
                width: 96,
                decimal: false,
                onChanged: _onSalePriceChanged,
              ),
              const Text(' сум', style: _kCellBold),
            ],
          ),
          if (info.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                info,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
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
          // decimal — FOIZ maydoni (12.5% bo'lishi mumkin), guruhlanmaydi;
          // aks holda PUL — yozayotganda har 3 xonadan probel (200 000).
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          else
            ThousandsSeparatorInputFormatter(),
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
          // «Общее количество» — sarlavha jadvalidagi bilan AYNAN bir qiymat,
          // shu qatorda ham ko'rinib, joyida tahrirlanadi.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Общее количество:', style: _kCellBold),
              const SizedBox(width: 6),
              Container(
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _InlineIntCell(
                  value: c.totalPieces,
                  onValue: _gramMode ? _setGramBatchQty : _setTotalPieces,
                ),
              ),
              const SizedBox(width: 6),
              // Birlik yozuvi katakdan TASHQARIDA; полуфабрикатда bosilsa
              // шт ↔ гр almashadi.
              if (widget.product.isSemiFinished)
                _unitToggle()
              else
                Text(_unitShort, style: _kCellStyle),
            ],
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
                                      ? '${base.name} ( $_batchLabel )'
                                      : '[${_stageOfBase(base)}] ${base.name} '
                                          '( $_batchLabel )',
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
                        // Baza og'irligi pf qatorlar hissasi bilan.
                        _kgComma(techBaseWeightG(base, _productById)),
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
              rowKey: 'b$index.$j',
              onChanged: (updated) => _updateIngredient(index, j, updated),
              onLongPress: () => _deleteIngredient(index, j),
            ),

          // «+ Ингредиент» va «+ Полуфабрикат» qatorlari
          _addRow('+ Ингредиент', () => _addIngredient(index)),
          _addRow('+ Полуфабрикат', () => _addPfIngredient(index)),
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
                        'Расходник ( $_batchLabel )',
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
              rowKey: 'c$i',
              onChanged: (updated) => _updateConsumable(i, updated),
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

  // Qatorning «Цена»si admin QO'LDA kiritgan narxdanmi (xarid emas).
  // Полуфабрикат qatori narxni o'z tex kartasidan oladi — unga tegishli emas.
  bool _isManualPrice(TechItem item) =>
      !_isPfItem(item) && (_prices[item.productId]?.isManual ?? false);

  // «Цена» katagi bosildi — xarid narxi sheet'i (tepasida qo'lda narx
  // tahriri). Qo'lda narx saqlansa sheet `true` qaytaradi: mahsulot
  // keshlarini bekor qilib narxlarni qayta yuklaymiz, shunda «Цена»,
  // «Сумма» va «Себестоимость» kataklari darhol jonli yangilanadi.
  Future<void> _openPriceSheet(TechItem item) async {
    final changed = await showPriceHistorySheet(
      context,
      productId: item.productId,
      productName: item.name,
    );
    if (!mounted || changed != true) return;
    setState(() {
      _productByIdCache = null;
      _wasteFactorsCache = null;
    });
    await _loadPrices();
  }

  // Bir blokdagi ingredient qatori: nom | birlik | miqdor | Цена | Сумма.
  // Tahrir JOYIDA: miqdor katagi — inline TextField (g/ml da kg/litr sifatida
  // yoziladi), birlik katagi — bosilganda menyu. Long-press (nom katagida)
  // o'chiradi; Цена katagining o'z InkWell'i xarid tarixini ochadi.
  Widget _itemRow(
    TechItem item, {
    required ValueChanged<TechItem> onChanged,
    required VoidCallback onLongPress,
    required String rowKey,
  }) {
    final price = _rowUnitPrice(item);
    final cost = _rowCost(item);
    final noPrice = cost == null;
    final manual = !noPrice && _isManualPrice(item);
    final stale = !noPrice && !manual && _isStalePrice(item);
    final isPf = _isPfItem(item);
    // Ochish faqat tarkibi bor пф'da (bo'sh tex kartada ochadigan narsa yo'q).
    final canExpand = isPf &&
        (_productById[item.productId]?.techCard?.bases.isNotEmpty ?? false);
    final expanded = canExpand && _expandedPf.contains(rowKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: _kSide),
          ),
          child: InkWell(
            onLongPress: onLongPress,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: _kCellPad,
                      child: Row(
                        children: [
                          Flexible(child: Text(item.name, style: _kCellStyle)),
                          // Полуфабрикат belgisi — bosilsa ichidagi masalliqlar
                          // SHU qator ostida ochiladi/yopiladi.
                          if (isPf)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap:
                                  canExpand ? () => _togglePfRow(rowKey) : null,
                              child: _pfChip(
                                withIcon: canExpand,
                                expanded: expanded,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Birlik — bosilsa tanlash menyusi. 'g' ga o'tish шт mahsulotda
                  // og'irlik yo'q bo'lsa bloklanadi (backend konvert qila olmaydi).
                  PopupMenuButton<String>(
                    tooltip: 'Birlikni almashtirish',
                    itemBuilder: (_) => [
                      for (final u in kTechUnits)
                        PopupMenuItem(
                          value: u,
                          child: Text(_excelUnitLabel(u)),
                        ),
                    ],
                    onSelected: (u) {
                      if (u == item.unit) return;
                      // Полуфабрикат birligi O'Z tex kartasida belgilanadi: дона
                      // (шт rejimi) yoki гр (batch_unit 'g'). Дона'dagi пф'ni
                      // grammga o'tkazib bo'lmaydi va aksincha.
                      final pfBlocked = _pfUnitBlockedMessage(item, u);
                      if (pfBlocked != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(pfBlocked)));
                        return;
                      }
                      final blocked = _gramBlockedMessage(item);
                      if (u == 'g' && blocked != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(blocked)));
                        return;
                      }
                      onChanged(item.copyWith(unit: u));
                    },
                    child: Container(
                      width: _kUnitColW,
                      alignment: Alignment.center,
                      decoration:
                          const BoxDecoration(border: Border(left: _kSide)),
                      child:
                          Text(_excelUnitLabel(item.unit), style: _kCellStyle),
                    ),
                  ),
                  Container(
                    width: _kAmountColW,
                    alignment: Alignment.center,
                    decoration:
                        const BoxDecoration(border: Border(left: _kSide)),
                    child: _InlineAmountCell(
                      item: item,
                      onAmount: (v) => onChanged(item.copyWith(amount: v)),
                    ),
                  ),
                  // Цена: g/ml uchun 1 kg/l narxi, pcs/m uchun 1 birlik narxi.
                  // Qo'lda kiritilgan narx — och ko'k fon; eski narx
                  // (>30 kun) — sariq fon. Bosilsa narx sheet'i ochiladi
                  // (qo'lda narx tahriri + xarid tarixi).
                  _moneyCell(
                    noPrice ? '—' : fmtCostMoney(price!),
                    width: _kPriceColW,
                    grey: noPrice,
                    bg: manual
                        ? const Color(0xFFD6E9FB)
                        : (stale ? const Color(0xFFFFECB3) : null),
                    tooltip: manual ? 'Qo\'lda kiritilgan narx' : null,
                    onTap: item.productId != 0
                        ? () => _openPriceSheet(item)
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
        ),
        // Пф tarkibi — SHU qator ostida, ulushga ko'paytirilgan miqdorlar.
        if (expanded)
          ..._pfChildRows(
            item: item,
            factor: 1,
            depth: 0,
            parentKey: rowKey,
          ),
      ],
    );
  }

  // Pul katagi (Excel to'ri uslubida): o'ngga tekislangan, uzun sonlar
  // FittedBox bilan kichrayadi. grey=true — narx yo'q («—», kulrang).
  // bg — katak foni (qo'lda narx / eski narx belgisi); tooltip — fon nimani
  // anglatishi; onTap — katakning o'z tap maydoni (narx sheet'i).
  Widget _moneyCell(
    String text, {
    required double width,
    bool bold = false,
    bool grey = false,
    Color? bg,
    String? tooltip,
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
    final tapped = onTap == null ? cell : InkWell(onTap: onTap, child: cell);
    if (tooltip == null) return tapped;
    return Tooltip(message: tooltip, child: tapped);
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

// ---- Shakl (Размер) dialogi natijasi ----
// Doim izchil: '' — hammasi null, 'round' — faqat diametr, 'rect' — faqat
// eni/uzunlik. Hech qachon float bo'lmaydi — sm qiymatlari butun son.

class _ShapeResult {
  final String shape; // '' | 'round' | 'rect'
  final int? diameterCm;
  final int? widthCm;
  final int? lengthCm;
  final int? heightCm; // balandlik — round va rect uchun ixtiyoriy

  const _ShapeResult({
    required this.shape,
    this.diameterCm,
    this.widthCm,
    this.lengthCm,
    this.heightCm,
  });
}

// ---- Shakl tanlash dialogi: Круг / Прямоугольник / «-» ----
// Round — diametr maydoni, rect — ширина×длина maydonlari. Bo'sh qoldirilsa
// shakl «-» (belgilanmagan) deb saqlanadi.

class _ShapeDialog extends StatefulWidget {
  final String shape;
  final int? diameterCm;
  final int? widthCm;
  final int? lengthCm;
  final int? heightCm;

  const _ShapeDialog({
    required this.shape,
    this.diameterCm,
    this.widthCm,
    this.lengthCm,
    this.heightCm,
  });

  @override
  State<_ShapeDialog> createState() => _ShapeDialogState();
}

class _ShapeDialogState extends State<_ShapeDialog> {
  late String _shape;
  late final TextEditingController _diameterCtrl;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _heightCtrl;

  @override
  void initState() {
    super.initState();
    _shape = widget.shape;
    _diameterCtrl =
        TextEditingController(text: widget.diameterCm?.toString() ?? '');
    _widthCtrl = TextEditingController(text: widget.widthCm?.toString() ?? '');
    _lengthCtrl =
        TextEditingController(text: widget.lengthCm?.toString() ?? '');
    _heightCtrl =
        TextEditingController(text: widget.heightCm?.toString() ?? '');
  }

  @override
  void dispose() {
    _diameterCtrl.dispose();
    _widthCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  // Musbat butun son yoki null (bo'sh/0/xato).
  int? _posInt(TextEditingController ctrl) {
    final v = int.tryParse(ctrl.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  void _submit() {
    final h = _posInt(_heightCtrl); // balandlik ixtiyoriy (bo'sh = null)
    if (_shape == 'round') {
      final d = _posInt(_diameterCtrl);
      if (d == null && _diameterCtrl.text.trim().isNotEmpty) return; // 0 — xato
      Navigator.pop(
        context,
        d == null
            ? const _ShapeResult(shape: '')
            : _ShapeResult(shape: 'round', diameterCm: d, heightCm: h),
      );
      return;
    }
    if (_shape == 'rect') {
      final w = _posInt(_widthCtrl);
      final l = _posInt(_lengthCtrl);
      final bothEmpty =
          _widthCtrl.text.trim().isEmpty && _lengthCtrl.text.trim().isEmpty;
      if (bothEmpty) {
        Navigator.pop(context, const _ShapeResult(shape: ''));
        return;
      }
      if (w == null || l == null) return; // biri yetishmaydi — yopilmaydi
      Navigator.pop(
        context,
        _ShapeResult(shape: 'rect', widthCm: w, lengthCm: l, heightCm: h),
      );
      return;
    }
    Navigator.pop(context, const _ShapeResult(shape: ''));
  }

  Widget _numField(TextEditingController ctrl, String label,
      {bool autofocus = false}) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Размер'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<String>(
              groupValue: _shape,
              onChanged: (v) => setState(() => _shape = v ?? ''),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'round',
                    dense: true,
                    title: Text('Круг (диаметр)'),
                  ),
                  RadioListTile<String>(
                    value: 'rect',
                    dense: true,
                    title: Text('Прямоугольник (ширина×длина)'),
                  ),
                  RadioListTile<String>(
                    value: '',
                    dense: true,
                    title: Text('-'),
                  ),
                ],
              ),
            ),
            if (_shape == 'round') ...[
              const SizedBox(height: 8),
              _numField(_diameterCtrl, 'Диаметр (см)', autofocus: true),
            ],
            if (_shape == 'rect') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child:
                        _numField(_widthCtrl, 'Ширина (см)', autofocus: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×', style: _kCellBold),
                  ),
                  Expanded(child: _numField(_lengthCtrl, 'Длина (см)')),
                ],
              ),
            ],
            if (_shape == 'round' || _shape == 'rect') ...[
              const SizedBox(height: 8),
              _numField(_heightCtrl, 'Высота (см) — ixtiyoriy'),
            ],
          ],
        ),
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

// ---- Полуфабрикат miqdor dialogi ----
// Birlik TANLANMAYDI — пф'ning O'Z tex kartasi belgilaydi: batch_unit 'g'
// bo'lsa гр (unit 'g'), aks holda дона (unit 'pcs'). Дона'dagi пф grammga
// o'tmaydi (va aksincha) — birlik faqat пф tex kartasida шт↔гр bilan
// o'zgartiriladi.

class _PfAmountResult {
  final String unit; // 'pcs' | 'g'
  final int amount; // butun son (dona yoki gramm)

  const _PfAmountResult({required this.unit, required this.amount});
}

class _PfAmountDialog extends StatefulWidget {
  final String title;
  final int batchQty; // joriy karta partiyasi JAMI donasi (label uchun)
  final int pieceWeightG; // pf 1 dona og'irligi (дона rejimida ma'lumot uchun)
  // Пф partiyasi гр rejimidami (batch_unit 'g') — kiritish birligini shu
  // belgilaydi: true → гр, false → дона.
  final bool gramBatch;

  const _PfAmountDialog({
    required this.title,
    required this.batchQty,
    required this.pieceWeightG,
    this.gramBatch = false,
  });

  @override
  State<_PfAmountDialog> createState() => _PfAmountDialogState();
}

class _PfAmountDialogState extends State<_PfAmountDialog> {
  final TextEditingController _ctrl = TextEditingController();

  String get _unit => widget.gramBatch ? 'g' : 'pcs';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_ctrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    Navigator.pop(context, _PfAmountResult(unit: _unit, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.pieceWeightG;
    final hintStyle = TextStyle(fontSize: 12.5, color: Colors.grey.shade700);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Дона rejimida 1 dona og'irligi — faqat ma'lumot uchun.
          if (!widget.gramBatch && w > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('1 dona ≈ $w г', style: hintStyle),
            ),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _unit == 'g'
                  ? 'Necha гр (${widget.batchQty} talik partiya uchun)'
                  : 'Necha dona (${widget.batchQty} talik partiya uchun)',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
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
}

// ---- Matn kiritish dialogi (baza/bosqich nomi) ----
// O'z controllerini o'zi yaratadi va dispose qiladi (loyihadagi naqsh).
// (Son kiritish endi joyida — _InlineAmountCell/_InlineIntCell.)

class _TextFieldDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initial;

  const _TextFieldDialog({
    required this.title,
    required this.label,
    required this.initial,
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
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
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

// Miqdor katagining JOYIDA tahrirlanadigan maydoni. g/ml qatorlarda qiymat
// kg/litr sifatida yoziladi (masalan 1.5 -> 1500 gr, butun son saqlanadi),
// pcs/m da butun son. Har bir to'g'ri yozuv darhol modelga o'tadi (tannarx va
// og'irliklar jonli yangilanadi); fokus ketganda matn kanonik ko'rinishga
// («1.500») qaytadi. Bo'sh/xato yozuv commit qilinmaydi.
class _InlineAmountCell extends StatefulWidget {
  final TechItem item;
  final ValueChanged<int> onAmount;

  const _InlineAmountCell({required this.item, required this.onAmount});

  @override
  State<_InlineAmountCell> createState() => _InlineAmountCellState();
}

class _InlineAmountCellState extends State<_InlineAmountCell> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  bool get _isMilli => widget.item.unit == 'g' || widget.item.unit == 'ml';

  String get _canonical => _excelAmount(widget.item);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _canonical);
    _focus.addListener(() {
      // Fokus ketdi — oxirgi saqlangan qiymatning kanonik matni.
      if (!_focus.hasFocus && _controller.text != _canonical) {
        _controller.text = _canonical;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineAmountCell old) {
    super.didUpdateWidget(old);
    // Tashqi o'zgarish (masalan, birlik almashdi) — yozayotgan bo'lmasa sinxron.
    if (!_focus.hasFocus && _controller.text != _canonical) {
      _controller.text = _canonical;
    }
  }

  void _onText(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return;
    final int next;
    if (_isMilli) {
      final v = double.tryParse(t);
      if (v == null || v < 0) return;
      next = (v * 1000).round(); // kg/litr -> gr/ml, faqat butun son
    } else {
      final v = int.tryParse(t);
      if (v == null || v < 0) return;
      next = v;
    }
    if (next != widget.item.amount) widget.onAmount(next);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: TextAlign.center,
      style: _kCellStyle,
      keyboardType: _isMilli
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        _isMilli
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      onChanged: _onText,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }
}

// Sarlavha jadvalidagi butun-son katakni JOYIDA tahrirlash (Штук, Общее
// количество). Yozilgan to'g'ri qiymat darhol onValue orqali modelga o'tadi
// (clamp/yaxlitlashni chaqiruvchi qiladi); fokus ketganda matn modeldagi
// yakuniy qiymatga qaytadi. Bo'sh/xato yozuv commit qilinmaydi.
class _InlineIntCell extends StatefulWidget {
  final int value;
  final ValueChanged<int> onValue;
  final String? suffixText;

  const _InlineIntCell({
    required this.value,
    required this.onValue,
    this.suffixText,
  });

  @override
  State<_InlineIntCell> createState() => _InlineIntCellState();
}

class _InlineIntCellState extends State<_InlineIntCell> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  String get _canonical => widget.value.toString();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _canonical);
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text != _canonical) {
        _controller.text = _canonical;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineIntCell old) {
    super.didUpdateWidget(old);
    // Tashqi o'zgarish — yozayotgan bo'lmasa sinxron.
    if (!_focus.hasFocus && _controller.text != _canonical) {
      _controller.text = _canonical;
    }
  }

  void _onText(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null || v < 0) return;
    if (v != widget.value) widget.onValue(v);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: TextAlign.center,
      style: _kCellStyle,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        suffixText: widget.suffixText,
        suffixStyle: _kCellStyle,
      ),
      onChanged: _onText,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }
}
