// yuk/models/yuk_last_price_model.dart — GET /api/yuk/last-prices javobi:
// har mahsulotning OXIRGI birlik narxi (narxlashda «oldingi narx» ko'rsatish
// va keskin og'ishda ogohlantirish uchun). products — katalog id bo'yicha,
// names — nom kaliti (kichik harf, ortiqcha bo'shliqsiz) bo'yicha (katalog
// ham, katalogda yo'q qo'lda qo'shilgan nomlar ham).

/// Bitta mahsulotning oxirgi narxi: ko'rinadigan birlik boshiga (кг/л
/// mahsulotda kg/l boshiga), butun so'm.
class YukLastPrice {
  final int price;
  final String unit;
  final String date; // YYYY-MM-DD

  const YukLastPrice({required this.price, this.unit = '', this.date = ''});

  factory YukLastPrice.fromJson(Map<String, dynamic> json) => YukLastPrice(
        price: (json['price'] as num?)?.round() ?? 0,
        unit: json['unit']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
      );

  /// "13.08" ko'rinishidagi qisqa sana (bo'sh bo'lsa bo'sh).
  String get shortDate =>
      date.length >= 10 ? '${date.substring(8, 10)}.${date.substring(5, 7)}' : date;
}

/// Backend nom kaliti bilan bir xil (productNameKey): trim + ketma-ket
/// bo'shliqlar bitta + kichik harf.
String yukNameKey(String name) =>
    name.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();

/// Qo'lda qo'shilgan itemlarning sintetik product_id'lari shu qiymatdan
/// boshlanadi (backend addedItemIDBase) — ular GLOBAL mahsulot emas, oxirgi
/// narx faqat nom bo'yicha qaraladi.
const int kYukAddedItemIdBase = 1000000;

class YukLastPrices {
  final Map<int, YukLastPrice> byProduct;
  final Map<String, YukLastPrice> byName;

  const YukLastPrices({this.byProduct = const {}, this.byName = const {}});

  bool get isEmpty => byProduct.isEmpty && byName.isEmpty;

  factory YukLastPrices.fromJson(dynamic data) {
    if (data is! Map) return const YukLastPrices();
    final products = <int, YukLastPrice>{};
    final names = <String, YukLastPrice>{};
    final p = data['products'];
    if (p is Map) {
      p.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v is Map) {
          products[id] = YukLastPrice.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    final n = data['names'];
    if (n is Map) {
      n.forEach((k, v) {
        if (v is Map) {
          names[k.toString()] =
              YukLastPrice.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    return YukLastPrices(byProduct: products, byName: names);
  }

  /// Katalog item — id bo'yicha (bo'lmasa nom bo'yicha); qo'lda qo'shilgan
  /// (sintetik id) yoki id'siz item — faqat nom bo'yicha.
  YukLastPrice? lookup({int productId = 0, String name = ''}) {
    if (productId > 0 && productId < kYukAddedItemIdBase) {
      final p = byProduct[productId];
      if (p != null) return p;
    }
    final key = yukNameKey(name);
    if (key.isEmpty) return null;
    return byName[key];
  }
}

/// Joriy birlik narxning oldingi narxdan og'ishi (ulush, masalan 0.35 = +35%).
/// Oldingi narx bo'lmasa null. Bu chegaradan (`kYukPriceWarnRatio`) katta
/// og'ish — ehtimoliy kiritish xatosi (kg o'rniga gramm, nol ko'p/kam).
double? yukPriceDeviation(double unitPrice, YukLastPrice? prev) {
  if (prev == null || prev.price <= 0 || unitPrice <= 0) return null;
  return (unitPrice - prev.price) / prev.price;
}

/// Shu ulushdan katta og'ishda ogohlantirish ko'rsatiladi (30%).
const double kYukPriceWarnRatio = 0.30;

/// Shu ulushdan katta og'ishda (3 marta va undan ko'p — +200% yoki −67%)
/// yuborishdan oldin alohida tasdiq so'raladi (`_confirmPriceOutliers`).
const double kYukPriceBlockRatio = 0.67;
