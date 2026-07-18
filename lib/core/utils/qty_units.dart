/// Miqdor birliklari uchun yagona manba.
///
/// API KONTRAKT: birligi (type) кг-oilasi (кг/kg/кл) yoki л-oilasi
/// (л/литр/l/litr) bo'lgan mahsulotlarda API orqali yuradigan HAR QANDAY
/// miqdor — BUTUN gramm/millilitr (1.5 kg -> 1500). Boshqa birliklar
/// (шт, гр, мл, пачка, порция, упаковка, м) o'zgarmagan.
/// UI'da esa foydalanuvchi hamon kg/l ko'radi va kiritadi.
library;

/// кг/л mahsulotlar API'da BUTUN gr/ml sifatida yuradi (1.5 kg -> 1500).
int qtyUnitFactor(String? type) {
  final t = (type ?? '').trim().toLowerCase();
  switch (t) {
    case 'кг':
    case 'kg':
    case 'кл':
    case 'л':
    case 'литр':
    case 'l':
    case 'litr':
      return 1000;
    default:
      return 1;
  }
}

/// API qiymatini (gramm/ml) UI qiymatiga (kg/l) o'giradi.
double qtyToUi(num apiQty, String? type) => apiQty / qtyUnitFactor(type);

/// UI'da kiritilgan (kg/l) qiymatni API butun soniga o'giradi.
num qtyFromUi(num uiQty, String? type) {
  final f = qtyUnitFactor(type);
  if (f == 1) return uiQty;
  return (uiQty * f).round();
}

/// Qo'lda teriladigan кг/л maydon qiymatini API soniga o'giradi — GRAMM-YOZISH
/// HIMOYASI bilan. Omborchilar кг/л maydonga ko'pincha GRAMM yozadi ("20 kg"
/// o'rniga "20000") va qiymat ×1000 bo'lib 20 TONNA bo'lib ketardi. Bozorda
/// bitta buyurtmada 1000 kg/l dan katta mahsulot bo'lmaydi (real maksimum
/// Сахар ~500 kg) — shuning uchun 1000 va undan katta qiymat GRAMM/МЛ deb
/// qabul qilinadi va ko'paytirilmaydi (backend legacyQtyIn bilan bir xil
/// qoida). 1000 dan kichigi odatdagidek kg/l deb ×1000 qilinadi.
num qtyFromUiSafe(num uiQty, String? type) {
  final f = qtyUnitFactor(type);
  if (f != 1 && uiQty >= 1000) return uiQty.round();
  return qtyFromUi(uiQty, type);
}

/// API miqdorini UI ko'rinishida formatlaydi (max 3 kasr, oxirgi nollar olib
/// tashlanadi): 1500 (кг) -> "1.5", 2000 (кг) -> "2", 7 (шт) -> "7".
String formatQty(num apiQty, String? type) {
  final ui = qtyToUi(apiQty, type);
  if (ui == ui.roundToDouble()) return ui.toInt().toString();
  return ui.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
}

/// "1.5 кг" ko'rinishida formatlaydi.
String formatQtyUnit(num apiQty, String? type) =>
    '${formatQty(apiQty, type)} ${type ?? ''}'.trim();
