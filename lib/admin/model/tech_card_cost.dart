// Tex karta tannarx matematikasi — YAGONA manba (sof funksiyalar).
// TechCardEditorPage (jonli hisob kataklari) va «Foyda nazorati» ekrani
// (ProfitControlUi) ikkalasi ham shu helperlar bilan hisoblaydi.
//
// Belgilashlar:
//   C0 — 1 dona MASALLIQ tannarxi (bazalar + расходник, tozalash yo'qotishi
//        koeffitsiyentlari qo'llangan) — techIngredientPieceCost.
//   C  — 1 dona TO'LIQ tannarxi = C0 + dop. rasxod — techFullPieceCost.
//
// Narx manbai — GET /api/prices/latest (LatestPrice.unitPrice ENG KICHIK
// birlik narxi: кг/л uchun 1 gr/ml, шт uchun 1 dona, м uchun 1 metr).

import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/production/models/latest_price_model.dart';

// Mahsulotlar ro'yxatidan tozalash yo'qotishi koeffitsiyentlari xaritasi
// (faqat factor != 1 bo'lganlar — xarid narxi shu koeffitsiyentga
// ko'paytiriladi, backend /api/production/cost ham xuddi shunday qiladi).
Map<int, double> techWasteFactors(List<ProductModelAdmin> products) => {
      for (final p in products)
        if (p.wasteFactor != 1) p.id: p.wasteFactor,
    };

// Qator tannarxi (PARTIYA uchun): amount * unit_price * wasteFactor.
// amount ham, unit_price ham ENG KICHIK birlikda — to'g'ridan-to'g'ri
// ko'paytma. null — narx yo'q (product_id=0 yoki hech narxlanmagan).
double? techRowCost(
  TechItem item,
  Map<int, LatestPrice> prices,
  Map<int, double> wasteFactors,
) {
  if (item.productId == 0) return null;
  final p = prices[item.productId];
  if (p == null) return null;
  return item.amount * p.unitPrice * (wasteFactors[item.productId] ?? 1);
}

// Qatorda ko'rsatiladigan «Цена»: g/ml uchun 1 kg/l narxi (x1000),
// pcs/m uchun o'z birligi narxi. null — narx yo'q.
double? techRowUnitPrice(TechItem item, Map<int, LatestPrice> prices) {
  if (item.productId == 0) return null;
  final p = prices[item.productId];
  if (p == null) return null;
  return (item.unit == 'g' || item.unit == 'ml')
      ? p.unitPrice * 1000
      : p.unitPrice;
}

// Narxi bor qatorlarning yig'indisi (narxsizlar hisobga olinmaydi).
double techItemsCost(
  List<TechItem> items,
  Map<int, LatestPrice> prices,
  Map<int, double> wasteFactors,
) {
  double sum = 0;
  for (final it in items) {
    sum += techRowCost(it, prices, wasteFactors) ?? 0;
  }
  return sum;
}

// Partiya masalliq tannarxi = barcha bazalar + расходник.
double techBatchCost(
  TechCard card,
  Map<int, LatestPrice> prices,
  Map<int, double> wasteFactors,
) {
  double sum = techItemsCost(card.consumables, prices, wasteFactors);
  for (final base in card.bases) {
    sum += techItemsCost(base.ingredients, prices, wasteFactors);
  }
  return sum;
}

// C0 — 1 dona masalliq tannarxi. batchQty<=0 bo'lsa 0 (hisoblab bo'lmaydi).
double techIngredientPieceCost(
  TechCard card,
  Map<int, LatestPrice> prices,
  Map<int, double> wasteFactors,
) {
  if (card.batchQty <= 0) return 0;
  return techBatchCost(card, prices, wasteFactors) / card.batchQty;
}

// Dop. rasxod 1 dona uchun (so'm). 'percent' — C0 dan foiz, 'sum' — so'm,
// belgilanmagan ('') — 0.
double techOverheadPerPiece(String mode, double value, double c0) {
  if (mode == 'percent') return c0 * value / 100;
  if (mode == 'sum') return value;
  return 0;
}

// C — 1 dona TO'LIQ tannarx = C0 + dop. rasxod.
double techFullPieceCost(String overheadMode, double overheadValue, double c0) =>
    c0 + techOverheadPerPiece(overheadMode, overheadValue, c0);

// 1 dona foyda (so'm) — TO'LIQ tannarx C ga nisbatan.
// null — foyda belgilanmagan yoki percent rejimida C noma'lum/0.
double? techProfitPerPiece(String mode, double value, double fullCost) {
  if (mode == 'sum') return value;
  if (mode == 'percent') {
    if (fullCost <= 0) return null;
    return fullCost * value / 100;
  }
  return null;
}

// Foyda foizda (C ga nisbatan). null — hisoblab bo'lmaydi.
double? techProfitPercent(String mode, double value, double fullCost) {
  if (mode == 'percent') return value;
  if (mode == 'sum') {
    if (fullCost <= 0) return null;
    return value * 100 / fullCost;
  }
  return null;
}

// Eng yaqin 1000 ga yaxlitlash: 287 634 -> 288 000, 287 400 -> 287 000.
int roundTo1000(double v) => (v / 1000).round() * 1000;

// Tavsiya etiladigan sotish narxi = roundTo1000(C + foyda).
// null — foyda belgilanmagan yoki C noma'lum/0.
int? techSuggestedSalePrice(
  String profitMode,
  double profitValue,
  double fullCost,
) {
  if (fullCost <= 0) return null;
  final profit = techProfitPerPiece(profitMode, profitValue, fullCost);
  if (profit == null) return null;
  return roundTo1000(fullCost + profit);
}

// Marja foizi: (narx − C) / C × 100. null — C noma'lum/0.
double? techMarginPercent(num salePrice, double fullCost) {
  if (fullCost <= 0) return null;
  return (salePrice - fullCost) / fullCost * 100;
}

// Tex kartada tarkib bormi (bo'sh kartalar «Foyda nazorati»ga kirmaydi).
bool techCardHasContent(TechCard? card) {
  if (card == null) return false;
  return card.bases.any((b) => b.ingredients.isNotEmpty) ||
      card.consumables.isNotEmpty;
}

// Sotish narxi ALMASHTIRILISHI kerak mahsulotlar soni: tavsiya hisoblanadi
// va saqlangan sale_price dan farq qiladi (hali belgilanmagani ham kiradi).
// Admin bosh sahifadagi badge va «Foyda nazorati» shu qoida bilan ishlaydi.
int techPriceReplaceCount(
  List<ProductModelAdmin> products,
  Map<int, LatestPrice> prices,
) {
  if (prices.isEmpty) return 0;
  final wasteFactors = techWasteFactors(products);
  int n = 0;
  for (final p in products) {
    final card = p.techCard;
    if (!techCardHasContent(card)) continue;
    final c0 = techIngredientPieceCost(card!, prices, wasteFactors);
    final full = techFullPieceCost(card.overheadMode, card.overheadValue, c0);
    final suggested =
        techSuggestedSalePrice(card.profitMode, card.profitValue, full);
    if (suggested != null && suggested > 0 && suggested != card.salePrice) n++;
  }
  return n;
}
