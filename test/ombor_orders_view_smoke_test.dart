// test/ombor_orders_view_smoke_test.dart — OmborOrdersView (ombor buyurtmalari
// ro'yxati) uchun smoke test. Asosiy maqsad — REGRESSIYA QO'RIQCHISI: ro'yxat
// LAZY qolishi kerak (40 qatorli buyurtmada ham faqat ekrandagi qatorlar
// quriladi). Eski versiya hamma qatorni birdan qurib, iPhone'da ham qotib
// ilovani o'ldirardi.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/ombor/models/ombor_order_model.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_orders_ui.dart';

OmborOrderItem _item(int id, String name, {bool accepted = false}) =>
    OmborOrderItem(
      productId: id,
      name: name,
      count: 3000,
      type: 'кг',
      taken: 2500,
      subtotal: 50000,
      received: accepted ? 2500 : 0,
      accepted: accepted,
    );

OmborOrder _order(int id, String sklad, List<OmborOrderItem> items) => OmborOrder(
      id: id,
      orderId: '26-07-01-$id',
      skladName: sklad,
      status: 'narxlandi',
      total: 100000,
      created: '2026-07-01T09:15:00',
      items: items,
    );

void main() {
  setUpAll(() {
    if (!sl.isRegistered<Dio>()) sl.registerSingleton<Dio>(Dio());
  });

  testWidgets('ro\'yxat chiziladi va yozish faqat kerakli joyni yangilaydi',
      (tester) async {
    final provider = OmborProvider();
    // 40 ta mahsulotli katta buyurtma — eski versiya shu yerda qotardi.
    provider.myOrders = [
      _order(2, 'Asosiy sklad', [
        for (var i = 0; i < 40; i++)
          _item(i, 'Mahsulot $i', accepted: i.isEven),
      ]),
      _order(1, 'Ikkinchi sklad', [_item(100, 'Un')]),
    ];
    // initState'dagi fetch tarmoqqa chiqmasin.
    provider.isLoadingOrders = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<OmborProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: OmborOrdersView())),
      ),
    );
    await tester.pump(); // postFrame fetch (guard tufayli darhol qaytadi)

    provider.isLoadingOrders = false;
    provider.notifyListeners();
    await tester.pump();

    // Sklad sarlavhasi va birinchi qatorlar ko'rinadi.
    expect(find.text('Asosiy sklad'), findsOneWidget);
    expect(find.text('Mahsulot 0'), findsOneWidget);

    // LAZY: 40 ta qatordan faqat ekranga sig'gani qurilgan bo'lishi kerak.
    final builtFields = find.byType(TextField).evaluate().length;
    expect(builtFields, lessThan(15),
        reason: 'ro\'yxat lazy emas — hamma qator qurilyapti');

    // Tahrirlanadigan qatorga son yozamiz — istisno bo'lmasligi kerak.
    await tester.enterText(find.byType(TextField).first, '2.4');
    await tester.pump();
    expect(find.text('2.4'), findsOneWidget);
    // Kamomad belgisi chiqdi (taken 2500 gr, kelgani 2400 gr).
    expect(find.text('-0.1'), findsOneWidget);

    // Pastga scroll — qolgan qatorlar ham xatosiz quriladi.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pump();
    expect(find.text('Ikkinchi sklad'), findsOneWidget);

    // Yozilgan qiymat scroll'dan keyin ham saqlanadi.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 9000));
    await tester.pump();
    expect(find.text('2.4'), findsOneWidget);
  });

  testWidgets('bo\'sh holat', (tester) async {
    final provider = OmborProvider()..isLoadingOrders = true;
    await tester.pumpWidget(
      ChangeNotifierProvider<OmborProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: OmborOrdersView())),
      ),
    );
    await tester.pump();
    provider.isLoadingOrders = false;
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('Hozircha buyurtmalar yo\'q'), findsOneWidget);
  });
}
