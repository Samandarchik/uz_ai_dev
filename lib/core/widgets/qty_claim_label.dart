// core/widgets/qty_claim_label.dart — «2 → 1.8» yorlig'i: yuk keltiruvchi
// kiritgan son (claimed) bilan ombor tasdiqlagan son farq qilganda
// ko'rsatiladi. UCHALA ekran — yuk keltiruvchi, ombor, bugalter — shu YAGONA
// vidjetni ishlatadi, shuning uchun ko'rinish hamma joyda bir xil.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';

const Color _red = Color(0xFFC62828);
const Color _green = Color(0xFF2E7D32);

/// Ko'rsatiladigan farq bormi: ikkala son ham kiritilgan va teng emas.
/// (claimed = yuk aytgan, actual = ombor tasdiqlagan kelgan son.)
bool hasQtyClaimDiff(num claimed, num actual) =>
    claimed > 0 && actual > 0 && (claimed - actual).abs() > 0.0001;

/// «2 → 1.8»: kiritilgan son chizilgan, kelgan son rangli (kam kelsa qizil,
/// ortiq kelsa yashil). Farq bo'lmasa `SizedBox.shrink()` qaytadi — chaqiruvchi
/// shartsiz qo'shaverishi mumkin.
Widget qtyClaimLabel({
  required num claimed,
  required num actual,
  String? type,
  double fontSize = 12,
  bool withUnit = false,
  TextAlign textAlign = TextAlign.start,
}) {
  if (!hasQtyClaimDiff(claimed, actual)) return const SizedBox.shrink();
  final unit = withUnit && (type ?? '').isNotEmpty ? ' $type' : '';
  final less = actual < claimed;
  return RichText(
    textAlign: textAlign,
    text: TextSpan(
      style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600),
      children: [
        TextSpan(
          text: formatQty(claimed, type),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
        const TextSpan(text: ' → '),
        TextSpan(
          text: '${formatQty(actual, type)}$unit',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: less ? _red : _green,
          ),
        ),
      ],
    ),
  );
}
