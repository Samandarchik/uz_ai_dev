// pieceWeightFromName — real katalog nomlari bo'yicha (2026-08-25 prod ro'yxati).
import 'package:flutter_test/flutter_test.dart';
import 'package:uz_ai_dev/core/utils/piece_weight.dart';

void main() {
  test('aniq «1шт=…» ko\'rinishlari', () {
    expect(pieceWeightFromName('Lactel Сливочное Масло 1шт=200гр', 'кг'), 200);
    expect(pieceWeightFromName('Корица палочки 1 шт = 100гр', 'кг'), 100);
    expect(pieceWeightFromName('Мёд Алекс 1шт=1кг', 'кг'), 1000);
    expect(pieceWeightFromName('Berg вода Капсула 1шт=10л', 'л'), 10000);
    expect(pieceWeightFromName('Уксус 1шт=0,250Литр', 'л'), 250);
    expect(pieceWeightFromName('Кетчуп Хаинс 1шт=0,800гр', 'кг'), 800);
    expect(pieceWeightFromName('Дрожжи живые 1 пачка=500гр', 'кг'), 500);
    expect(pieceWeightFromName('Мука Дилбар 1 мешок=25кг', 'кг'), 25000);
    expect(pieceWeightFromName('Ванилин Кент 1щт=200гр', 'кг'), 200);
    expect(pieceWeightFromName('Паста Пене “Barilla” 1шт=450гр.', 'кг'), 450);
    expect(pieceWeightFromName('Ягодный сироп 1 лт = 1,290 кг', 'кг'), 1290);
    expect(pieceWeightFromName('Картофель Фри пф 1шт=2.5 кг', 'кг'), 2500);
  });

  test('qavs va oxiridagi gramm', () {
    expect(pieceWeightFromName('Сыр ханский (400гр)', 'кг'), 400);
    expect(pieceWeightFromName('Батончик Твикс (55гр)', 'кг'), 55);
    expect(pieceWeightFromName('Салатный лист 150 гр', 'кг'), 150);
    expect(pieceWeightFromName('Айсберг 300гр', 'кг'), 300);
    expect(pieceWeightFromName('Золотой декор 100гр', 'кг'), 100);
  });

  test('noaniq nomlar o\'qilmaydi', () {
    expect(pieceWeightFromName('Помидоры 4Кг', 'кг'), isNull);
    expect(pieceWeightFromName('Морковь 1Кг', 'кг'), isNull);
    expect(pieceWeightFromName('Сыр Лабне (750гр) (400гр)', 'кг'), isNull);
    expect(pieceWeightFromName('Шоколад Biscolata (32гр/40гр)', 'кг'), isNull);
    expect(pieceWeightFromName('5064 (PASTA NOCCIOLA) 2*5кг', 'кг'), isNull);
    expect(pieceWeightFromName('Гушт', 'кг'), isNull);
    // шт birlikli mahsulotga tegishli emas.
    expect(pieceWeightFromName('Сыр ханский (400гр)', 'шт'), isNull);
  });
}
