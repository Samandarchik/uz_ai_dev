// admin/model/product_model.dart — admin mahsulot modeli (ProductModelAdmin):
// fromJson/toJson, techCard (iyerarxik тех карта), composition (eski tekis
// tarkib), type, is_semi_finished (полуфабрикат), waste_base/waste_amount
// (tozalash yo'qotishi -> wasteFactor), mone_app/bozor/source/sklads (ombor →
// yuk keltiruvchi oqimi).
import 'package:uz_ai_dev/admin/model/composition_item.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';

class ProductModelAdmin {
  final int id;
  final String name;
  final int categoryId;
  final String type;
  final String? companyName;
  final num? grams;
  // Bozor (yuk keltiruvchi) oqimi uchun: 1 pachkaga qancha gramm
  final num? bozorGrams;
  final String categoryName;
  final String? imageUrl;
  final String? ingredients;

  final List<int> filials;
  final List<String> filialNames;

  // Ombor → yuk keltiruvchi oqimi uchun yangi maydonlar
  final bool moneApp;
  final bool bozor;
  final String source;
  final List<int> sklads;

  // Mahsulot tarkibi (eski tekis ingredientlar ro'yxati — saqlanadi, lekin
  // endi tahrirlash IERARXIK tex karta orqali bo'ladi).
  final List<CompositionItem> composition;

  // Yangi iyerarxik tex karta (tortlar uchun). null bo'lishi mumkin.
  final TechCard? techCard;

  // «Состав» switch yoqilganda eski erkin matn shu yerda saqlanadi
  final String? comment;

  // «Состав» tarkibdagi mahsulot nomlaridan to'lsa true bo'ladi
  final bool compositionAsIngredients;

  // Tozalash yo'qotishi (faqat кг/л oilasi uchun, gr/ml da butun son):
  // har wasteBase grammdan wasteAmount gramm yo'qoladi. 0/0 = yo'q.
  final int wasteBase;
  final int wasteAmount;

  // Полуфабрикат (yarim tayyor mahsulot, masalan «Классик бисквит»):
  // o'z tex kartasi va o'z qoldig'i (dona) bor, sotilmaydi — boshqa
  // mahsulotlarning tex kartasida ingredient sifatida ishlatiladi.
  // Backend pf mahsulotlarni seller/filial kataloglaridan avtomatik chiqaradi.
  final bool isSemiFinished;

  ProductModelAdmin({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    this.companyName,
    this.grams,
    this.bozorGrams,
    required this.categoryName,
    this.ingredients,
    this.imageUrl,
    required this.filials,
    required this.filialNames,
    this.moneApp = true,
    this.bozor = false,
    this.source = 'samarqand',
    this.sklads = const [],
    this.composition = const [],
    this.techCard,
    this.comment,
    this.compositionAsIngredients = false,
    this.wasteBase = 0,
    this.wasteAmount = 0,
    this.isSemiFinished = false,
  });

  // Tozalash yo'qotishi koeffitsiyenti: xarid narxi shu koeffitsiyentga
  // ko'paytiriladi (masalan 8000 dan 100 yo'qolsa — 8000/7900).
  // Noto'g'ri qiymatlarda 1 (ta'sir yo'q).
  double get wasteFactor {
    if (wasteBase > 0 && wasteAmount > 0 && wasteAmount < wasteBase) {
      return wasteBase / (wasteBase - wasteAmount);
    }
    return 1;
  }

  factory ProductModelAdmin.fromJson(Map<String, dynamic> json) {
    return ProductModelAdmin(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      grams: json['grams'],
      bozorGrams: json['bozor_grams'],
      type: json['type'] ?? '',
      ingredients: json['ingredients'],
      companyName: json['company_name'],
      imageUrl: json['image_url'],
      categoryName: json['category_name'] ?? '',
      filials: List<int>.from(json['filials'] ?? []),
      filialNames: List<String>.from(json['filial_names'] ?? []),
      moneApp: json['mone_app'] ?? true,
      bozor: json['bozor'] ?? false,
      source: (json['source'] == null ||
              (json['source'] as String).isEmpty)
          ? 'samarqand'
          : json['source'],
      sklads: (json['sklads'] as List?)?.map((e) => e as int).toList() ?? [],
      composition: CompositionItem.listFromJson(json['composition']),
      techCard: json['tech_card'] != null
          ? TechCard.fromJson(Map<String, dynamic>.from(json['tech_card']))
          : null,
      comment: json['comment']?.toString(),
      compositionAsIngredients: json['composition_as_ingredients'] ?? false,
      wasteBase: (json['waste_base'] as num?)?.toInt() ?? 0,
      wasteAmount: (json['waste_amount'] as num?)?.toInt() ?? 0,
      isSemiFinished: json['is_semi_finished'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'type': type,
      'company_name': companyName,
      'ingredients': ingredients,
      'image_url': imageUrl,
      'category_name': categoryName,
      'filials': filials,
      'filial_names': filialNames,
      'grams': grams,
      'bozor_grams': bozorGrams,
      'mone_app': moneApp,
      'bozor': bozor,
      'source': source,
      'composition': composition.map((e) => e.toJson()).toList(),
      'tech_card': techCard?.toJson(),
      'comment': comment,
      'composition_as_ingredients': compositionAsIngredients,
      'waste_base': wasteBase,
      'waste_amount': wasteAmount,
      'is_semi_finished': isSemiFinished,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'ingredients': ingredients,
      "company_name": companyName,
      'grams': grams,
      'bozor_grams': bozorGrams,
      'type': type,
      "image_url": imageUrl,
      'filials': filials,
      'mone_app': moneApp,
      'bozor': bozor,
      'source': source,
      'sklads': sklads,
      'composition': composition.map((e) => e.toJson()).toList(),
      'tech_card': techCard?.toJson(),
      'comment': comment,
      'composition_as_ingredients': compositionAsIngredients,
      'waste_base': wasteBase,
      'waste_amount': wasteAmount,
      'is_semi_finished': isSemiFinished,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'id': id,
      'name': name,
      'grams': grams,
      'bozor_grams': bozorGrams,
      'category_id': categoryId,
      'type': type,
      "company_name": companyName,
      "ingredients": ingredients,
      "image_url": imageUrl,
      'filials': filials,
      'mone_app': moneApp,
      'bozor': bozor,
      'source': source,
      'sklads': sklads,
      'composition': composition.map((e) => e.toJson()).toList(),
      'tech_card': techCard?.toJson(),
      'comment': comment,
      'composition_as_ingredients': compositionAsIngredients,
      'waste_base': wasteBase,
      'waste_amount': wasteAmount,
      'is_semi_finished': isSemiFinished,
    };
  }

  ProductModelAdmin copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? type,
    num? grams,
    num? bozorGrams,
    String? companyName,
    String? categoryName,
    String? ingredients,
    List<int>? filials,
    String? imageUrl,
    List<String>? filialNames,
    bool? moneApp,
    bool? bozor,
    String? source,
    List<int>? sklads,
    List<CompositionItem>? composition,
    TechCard? techCard,
    String? comment,
    bool? compositionAsIngredients,
    int? wasteBase,
    int? wasteAmount,
    bool? isSemiFinished,
  }) {
    return ProductModelAdmin(
      id: id ?? this.id,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      bozorGrams: bozorGrams ?? this.bozorGrams,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      companyName: companyName ?? this.companyName,
      ingredients: ingredients ?? this.ingredients,
      categoryName: categoryName ?? this.categoryName,
      filials: filials ?? this.filials,
      imageUrl: imageUrl ?? this.imageUrl,
      filialNames: filialNames ?? this.filialNames,
      moneApp: moneApp ?? this.moneApp,
      bozor: bozor ?? this.bozor,
      source: source ?? this.source,
      sklads: sklads ?? this.sklads,
      composition: composition ?? this.composition,
      techCard: techCard ?? this.techCard,
      comment: comment ?? this.comment,
      compositionAsIngredients:
          compositionAsIngredients ?? this.compositionAsIngredients,
      wasteBase: wasteBase ?? this.wasteBase,
      wasteAmount: wasteAmount ?? this.wasteAmount,
      isSemiFinished: isSemiFinished ?? this.isSemiFinished,
    );
  }
}
