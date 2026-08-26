// test/sh5_handover_count_test.dart — Sh5HandoverCountUi (smena topshirish
// sanog'i) uchun smoke test. Asosiy maqsad: son maydoni qatorning O'ZIDA
// tahrirlanishi (dialog CHIQMASLIGI) va farq sanog'i shu zahoti yangilanishi.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uz_ai_dev/admin/model/sh5_handover_model.dart';
import 'package:uz_ai_dev/admin/ui/sh5_handover_ui.dart';
import 'package:uz_ai_dev/core/di/di.dart';

Sh5HandoverDraft _draft() => Sh5HandoverDraft(
      skladId: 1,
      skladName: 'SMOKE BAR',
      takenAt: DateTime(2026, 8, 25, 21),
      items: const [
        Sh5DraftItem(rid: 1, name: 'Kola', unit: 'шт', sh5Milli: 10000),
        Sh5DraftItem(rid: 2, name: 'Pivo', unit: 'шт', sh5Milli: 4000),
      ],
    );

void main() {
  setUpAll(() {
    if (!sl.isRegistered<Dio>()) sl.registerSingleton<Dio>(Dio());
  });

  testWidgets('son qator ichida tahrirlanadi — dialog chiqmaydi', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Sh5HandoverCountUi.submit(
        skladId: 1,
        skladName: 'SMOKE BAR',
        draft: _draft(),
      ),
    ));
    await t.pumpAndSettle();

    // Boshlanishida: har tovarga bitta maydon, StoreHouse soni bilan to'ldirilgan.
    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    expect(find.widgetWithText(TextField, '4'), findsOneWidget);
    expect(find.text('2 ta tovar • farq yo\'q'), findsOneWidget);

    // Maydonni bosish — dialog OCHILMASLIGI kerak (eski xatti-harakat).
    await t.tap(find.widgetWithText(TextField, '10'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Joyida yozamiz: 10 → 9. Farq darhol hisoblanadi.
    await t.enterText(find.widgetWithText(TextField, '10'), '9');
    await t.pump();
    expect(find.text('1 ta pozitsiyada farq'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);

    // Tayanch songa qaytarilsa farq yo'qoladi.
    await t.enterText(find.widgetWithText(TextField, '9'), '10');
    await t.pump();
    expect(find.text('2 ta tovar • farq yo\'q'), findsOneWidget);
  });

  testWidgets('qabul rejimida tayanch son — topshirilgan miqdor', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Sh5HandoverCountUi.accept(
        skladId: 1,
        skladName: 'SMOKE BAR',
        open: const Sh5Handover(
          id: 1,
          skladId: 1,
          skladName: 'SMOKE BAR',
          outUserName: 'Kechki kassir',
          items: [
            Sh5HandoverItem(
                rid: 1,
                name: 'Kola',
                unit: 'шт',
                sh5Milli: 10000,
                outMilli: 10000),
          ],
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.textContaining('Topshirilgan: 10'), findsOneWidget);
    // Kassir 9 ta sanadi — kamomad qatorda ko'rinadi.
    await t.enterText(find.widgetWithText(TextField, '10'), '9');
    await t.pump();
    expect(find.text('−1'), findsOneWidget);
    expect(find.text('1 ta pozitsiyada farq'), findsOneWidget);
  });

  test('sh5MilliFromInput — kasr, vergul va noto\'g\'ri matn', () {
    expect(sh5MilliFromInput('9'), 9000);
    expect(sh5MilliFromInput('1.5'), 1500);
    expect(sh5MilliFromInput('1,5'), 1500);
    expect(sh5MilliFromInput(''), isNull);
    expect(sh5MilliFromInput('abc'), isNull);
    expect(sh5MilliFromInput('-2'), isNull);
  });
}
