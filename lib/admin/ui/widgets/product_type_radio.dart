import 'package:flutter/material.dart';

/// Mahsulot birligi (type) uchun yagona kanonik ro'yxat — hammasi kichik harfda.
const List<String> kProductTypeOptions = [
  'шт',
  'кг',
  'гр',
  'л',
  'мл',
  'пачка',
  'порция',
  'упаковка',
  'м',
];

/// Eski/xato yozilgan qiymatlarni kanonik kichik-harf shaklga keltiradi
/// (katta harf, ortiqcha probel, lotincha "p", "литр"→"л", "кл"→"кг").
String normalizeProductType(String raw) {
  final t = raw.trim().toLowerCase().replaceAll('p', 'р');
  const map = {'литр': 'л', 'кл': 'кг'};
  return map[t] ?? t;
}

/// Тип (birlik) tanlovi — radio buttonlar bilan.
/// Ro'yxatda bo'lmagan eski qiymat kelsa, u ham variant sifatida ko'rsatiladi.
class ProductTypeRadioGroup extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const ProductTypeRadioGroup({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(kProductTypeOptions);
    if (value != null && value!.isNotEmpty && !options.contains(value)) {
      options.add(value!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        RadioGroup<String>(
          groupValue: value,
          onChanged: onChanged,
          child: Wrap(
            children: options.map((t) {
              return SizedBox(
                width: 120,
                child: RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t),
                  value: t,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
