// Pul kiritish formatteri: guruhlash (200 000), kursor o'z joyida qolishi
// va parse (probelli matndan butun so'm).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uz_ai_dev/core/utils/money_input.dart';

// Matnni maydonga «yozish»ni taqlid qiladi: har bir belgi kursor joyiga
// qo'yiladi va formatter o'tkaziladi.
TextEditingValue type(String keys) {
  final f = ThousandsSeparatorInputFormatter();
  var value = const TextEditingValue();
  for (final ch in keys.split('')) {
    final at = value.selection.end < 0 ? value.text.length : value.selection.end;
    final next = value.text.substring(0, at) + ch + value.text.substring(at);
    value = f.formatEditUpdate(
      value,
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: at + 1),
      ),
    );
  }
  return value;
}

void main() {
  test('yozayotganda har 3 xonadan probel qo\'yiladi', () {
    expect(type('2').text, '2');
    expect(type('20').text, '20');
    expect(type('200').text, '200');
    expect(type('2000').text, '2 000');
    expect(type('200000').text, '200 000');
    expect(type('1234567').text, '1 234 567');
  });

  test('kursor oxirida qoladi', () {
    final v = type('200000');
    expect(v.selection.end, v.text.length);
  });

  test('matn ICHIDA tahrir qilinganda kursor sakramaydi', () {
    final f = ThousandsSeparatorInputFormatter();
    // «20 000» ning boshiga 1 yozamiz -> «120 000», kursor 1-raqamdan keyin.
    const before = TextEditingValue(
      text: '20 000',
      selection: TextSelection.collapsed(offset: 0),
    );
    final after = f.formatEditUpdate(
      before,
      const TextEditingValue(
        text: '120 000',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(after.text, '120 000');
    expect(after.selection.end, 1); // «1» dan keyin, oxiriga sakramagan
  });

  test('raqam bo\'lmagan belgilar tushiriladi, bo\'sh matn bo\'sh qoladi', () {
    expect(type('12a3').text, '123');
    final f = ThousandsSeparatorInputFormatter();
    expect(
      f.formatEditUpdate(const TextEditingValue(text: '200'),
          const TextEditingValue(text: '')).text,
      '',
    );
  });

  test('parseMoney probelli matndan butun so\'m beradi', () {
    expect(parseMoney('200 000'), 200000);
    expect(parseMoney('  1 234 567  '), 1234567);
    expect(parseMoney(''), 0);
    expect(parseMoney(null), 0);
    expect(parseMoney('—'), 0);
  });

  test('formatMoneyInput modeldagi sonni maydon matniga o\'giradi', () {
    expect(formatMoneyInput(200000), '200 000');
    expect(formatMoneyInput(0), '0');
    expect(formatMoneyInput(1500.6), '1 501'); // yaxlitlanadi
    expect(formatMoneyInput(-2000), '-2 000');
  });

  test('format -> parse aylanishi qiymatni saqlaydi', () {
    for (final v in [1, 999, 1000, 200000, 18750, 1234567]) {
      expect(parseMoney(formatMoneyInput(v)), v);
    }
  });
}
