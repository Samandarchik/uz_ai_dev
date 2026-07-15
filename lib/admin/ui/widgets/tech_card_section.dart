import 'package:uz_ai_dev/admin/model/tech_card.dart';

// Tex karta (тех карта) holatini boshqaradigan controller.
// Parent ekran shuni yaratadi, save paytida build() chaqiradi va dispose qiladi.
// Tex karta TAHRIRI endi faqat TechCardEditorPage (Excel-uslub sahifa) da —
// eski inline TechCardSection vidjeti va unga qarashli base/consumables
// sahifalari o'lik kod sifatida o'chirilgan.
class TechCardController {
  int batchQty;
  int? diameterCm;
  // Bo'limlar (bosqichlar) — tex karta muharriridagi «Bo'limlar» qatori.
  final List<TechStage> stages;
  final List<TechBase> bases;
  final List<TechItem> consumables;

  // Foyda (ustama): '' | 'percent' | 'sum' va qiymati (foiz yoki so'm/dona).
  String profitMode;
  double profitValue;

  // Dop. rasxod: '' | 'percent' (C0 dan foiz) | 'sum' (so'm/dona) va qiymati.
  String overheadMode;
  double overheadValue;

  // Tasdiqlangan sotish narxi (so'm/dona, 0 — belgilanmagan). Faqat admin
  // «Almashtirish» bosganda o'zgaradi.
  int salePrice;

  TechCardController([TechCard? initial])
      : batchQty = (initial?.batchQty ?? 1) < 1 ? 1 : (initial?.batchQty ?? 1),
        diameterCm = initial?.diameterCm,
        stages = List<TechStage>.from(initial?.stages ?? const []),
        bases = List<TechBase>.from(initial?.bases ?? const []),
        consumables = List<TechItem>.from(initial?.consumables ?? const []),
        profitMode = initial?.profitMode ?? '',
        profitValue = initial?.profitValue ?? 0,
        overheadMode = initial?.overheadMode ?? '',
        overheadValue = initial?.overheadValue ?? 0,
        salePrice = initial?.salePrice ?? 0;

  // To'liq TechCard ni yig'ib qaytaradi (weight maydonlari mahalliy hisoblanadi).
  TechCard build() => TechCard(
        batchQty: batchQty < 1 ? 1 : batchQty,
        diameterCm: diameterCm,
        stages: List<TechStage>.from(stages),
        bases: List<TechBase>.from(bases),
        consumables: List<TechItem>.from(consumables),
        profitMode: profitMode,
        profitValue: profitValue,
        overheadMode: overheadMode,
        overheadValue: overheadValue,
        salePrice: salePrice,
      );

  // «Состав» uchun showInSostav=true bo'lgan nomlar.
  List<String> sostavNames() => build().sostavNames();

  void dispose() {}
}
