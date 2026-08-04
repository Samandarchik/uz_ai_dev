// core/utils/money_input.dart — PUL kiritish maydonlari uchun YAGONA manba:
// ThousandsSeparatorInputFormatter (yozayotganda har 3 xonadan keyin probel —
// 200 000), formatMoneyInput (modeldagi sonni maydon matniga) va parseMoney
// (maydon matnidan BUTUN so'mga). Pul har doim butun so'm — tiyin yo'q.
//
// Ko'rsatish (matn sifatida chiqarish) uchun `fmtCostMoney` ishlatiladi
// (production/ui/widgets/cost_sheet.dart) — bu fayl faqat KIRITISH uchun.
import 'package:flutter/services.dart';

// Raqamlar qatorini o'ngdan 3 xonadan guruhlaydi: "200000" -> "200 000".
// Ajratuvchi — oddiy probel (fmtCostMoney bilan bir xil ko'rinish).
String groupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}

// Modeldagi pulni maydon matniga: 200000 -> "200 000". Manfiy qiymat
// oldiga "-" qo'yiladi (odatda uchramaydi).
String formatMoneyInput(num value) {
  final v = value.round();
  final text = groupThousands(v.abs().toString());
  return v < 0 ? '-$text' : text;
}

// Maydon matnidan BUTUN so'm: probel va boshqa belgilar tashlab yuboriladi
// ("200 000" -> 200000). Bo'sh/xato matn — 0.
int parseMoney(String? text) {
  final digits = (text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

// Pul maydonining formatteri: yozilayotgan paytda raqamlarni har 3 xonadan
// probel bilan guruhlaydi (200 000). Raqam bo'lmagan belgilar tushiriladi,
// shuning uchun `FilteringTextInputFormatter.digitsOnly` bilan birga
// ISHLATILMAYDI — buning o'zi yetarli.
//
// Kursor o'z JOYIDA qoladi: matn ichida (masalan boshida) tahrir qilinsa
// ham kursordan oldingi RAQAMLAR soni saqlanadi, ya'ni u matn oxiriga
// sakrab ketmaydi.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = groupThousands(digits);

    // Kursorgacha bo'lgan raqamlar soni — yangi matndagi o'rin shunga
    // qarab topiladi (probellar qo'shilgani kursorni surib yubormaydi).
    final end = newValue.selection.end;
    final int digitsBefore;
    if (end < 0) {
      digitsBefore = digits.length; // platforma o'rinni bermadi — oxiriga
    } else {
      digitsBefore = newValue.text
          .substring(0, end.clamp(0, newValue.text.length))
          .replaceAll(RegExp(r'[^0-9]'), '')
          .length;
    }

    var offset = 0;
    if (digitsBefore > 0) {
      var seen = 0;
      offset = formatted.length;
      for (var i = 0; i < formatted.length; i++) {
        final c = formatted.codeUnitAt(i);
        if (c >= 0x30 && c <= 0x39) seen++;
        if (seen == digitsBefore) {
          offset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
