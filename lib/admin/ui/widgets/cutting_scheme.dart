// admin/ui/widgets/cutting_scheme.dart — «Kesish sxemasi» diagrammasi:
// CuttingSchemeView — tex kartadagi shakl (round/rect) va partiya (Штук) dan
// tortni bo'laklarga kesish sxemasini 3D (yon-burchakdan, kabinet proyeksiya)
// chizadi. To'rtburchakda bo'lak kvadratga eng yaqin bo'ladigan ustun×qator
// to'ri, dumaloqda teng sektorlar; kesish chiziqlari old/yon yuzlarga tushadi.
// pieceSizeText() — bir bo'lak o'lchami matni (editor'dagi info blok uchun).
// Ranglar tort_30x50_10_bolak_kesish_sxemasi.svg namunasidan: tort FAEEDA,
// jigarrang ramka, punktir kesish chiziqlari, kulrang o'lchov strelkalari.
// 3D balandlik SAQLANMAYDI — faqat vizual (o'lchamdan taxminiy).
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---- Namuna SVG'dagi ranglar (old/yon yuzlar quyuqroq) ----
const Color _kCakeTop = Color(0xFFFAEEDA);
const Color _kCakeFront = Color(0xFFEFDABB);
const Color _kCakeSide = Color(0xFFE5C99F);
const Color _kCakeBorder = Color(0xFF854F0B);
const Color _kCutLine = Color(0xFFBA7517);
const Color _kNumber = Color(0xFF633806);
const Color _kArrow = Color(0xFF898781);
const Color _kLabel = Color(0xFF52514E);

const TextStyle _kNumberStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: _kNumber,
);
const TextStyle _kLabelStyle = TextStyle(fontSize: 11, color: _kLabel);

// sm qiymatini chiroyli yozadi: 15.0 → «15», 16.666 → «16.7».
String _fmtCm(double v) {
  final r = (v * 10).round() / 10;
  if (r == r.roundToDouble()) return r.round().toString();
  return r.toStringAsFixed(1);
}

// Vizual balandlik (sm) — saqlanmaydi, faqat 3D ko'rinish uchun.
double _rectHeightCm(int w, int l) =>
    (math.max(w, l) * 0.12).clamp(4.0, 10.0);
double _roundHeightCm(int d) => (d * 0.4).clamp(6.0, 12.0);

// Dumaloq tort usti ellipsining siqilish koeffitsienti (yon-burchak ko'rinish).
const double _kEllipseK = 0.38;

// pieces uchun eng yaxshi (ustun, qator) to'rini tanlaydi: bo'lak tomonlari
// nisbati (max/min) eng kichik — ya'ni bo'lak kvadratga eng yaqin bo'lsin.
// Tub sonlar uchun tabiiy ravishda 1×N chiziq chiqadi.
(int, int) _bestGrid(int pieces, int widthCm, int lengthCm) {
  var best = (1, pieces);
  double bestRatio = double.infinity;
  for (int cols = 1; cols <= pieces; cols++) {
    if (pieces % cols != 0) continue;
    final rows = pieces ~/ cols;
    final pw = widthCm / cols;
    final ph = lengthCm / rows;
    final ratio = math.max(pw, ph) / math.min(pw, ph);
    if (ratio < bestRatio) {
      bestRatio = ratio;
      best = (cols, rows);
    }
  }
  return best;
}

// Kesish sxemasi vidjeti (3D). Mavjud kenglikka moslashadi (balandlik shakl
// nisbatidan hisoblanadi, qat'iy piksel o'lchov yo'q).
class CuttingSchemeView extends StatelessWidget {
  final String shape; // 'round' | 'rect'
  final int? widthCm;
  final int? lengthCm;
  final int? diameterCm;
  final int pieces; // batchQty — nechta bo'lakka kesiladi

  const CuttingSchemeView({
    super.key,
    required this.shape,
    required this.pieces,
    this.widthCm,
    this.lengthCm,
    this.diameterCm,
  });

  bool get _isRect =>
      shape == 'rect' && (widthCm ?? 0) > 0 && (lengthCm ?? 0) > 0;

  bool get _isRound => shape == 'round' && (diameterCm ?? 0) > 0;

  // Bir bo'lak o'lchami matni: rect — «15 × 10 sm», round — «1/8 (⌀ 24 sm)».
  // Shakl to'liq kiritilmagan bo'lsa null.
  static String? pieceSizeText({
    required String shape,
    int? widthCm,
    int? lengthCm,
    int? diameterCm,
    required int pieces,
  }) {
    if (pieces < 1) return null;
    if (shape == 'rect' && (widthCm ?? 0) > 0 && (lengthCm ?? 0) > 0) {
      final (cols, rows) = _bestGrid(pieces, widthCm!, lengthCm!);
      return '${_fmtCm(widthCm / cols)} × ${_fmtCm(lengthCm / rows)} sm';
    }
    if (shape == 'round' && (diameterCm ?? 0) > 0) {
      return '1/$pieces (⌀ $diameterCm sm)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if ((!_isRect && !_isRound) || pieces < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final double height;
            final CustomPainter painter;
            if (_isRect) {
              final w = widthCm!, l = lengthCm!;
              painter =
                  _RectSidePainter(widthCm: w, lengthCm: l, pieces: pieces);
              final innerW = math.max(50.0,
                  maxW - _RectSidePainter.leftPad - _RectSidePainter.rightPad);
              final s = innerW / (w + _RectSidePainter.depthX * l);
              height = (_RectSidePainter.topPad +
                      _RectSidePainter.bottomPad +
                      s * (_rectHeightCm(w, l) - _RectSidePainter.depthY * l))
                  .clamp(150.0, 460.0);
            } else {
              final d = diameterCm!;
              painter = _RoundSidePainter(diameterCm: d, pieces: pieces);
              final innerW = math.max(50.0, maxW - 32);
              final p = innerW / d;
              height = (_RoundSidePainter.top +
                      _RoundSidePainter.bottom +
                      p * (_kEllipseK * d + _roundHeightCm(d)))
                  .clamp(150.0, 420.0);
            }
            return SizedBox(
              width: double.infinity,
              height: height,
              child: CustomPaint(painter: painter),
            );
          },
        ),
        const SizedBox(height: 4),
        const Text('Punktir chiziqlar — kesish joylari',
            textAlign: TextAlign.center, style: _kLabelStyle),
      ],
    );
  }
}

// ---- Umumiy chizish yordamchilari ----

void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
    {double dash = 5, double gap = 4}) {
  final total = (b - a).distance;
  if (total <= 0) return;
  final dir = (b - a) / total;
  double t = 0;
  while (t < total) {
    final end = math.min(t + dash, total);
    canvas.drawLine(a + dir * t, a + dir * end, paint);
    t = end + gap;
  }
}

// Ikki uchida chevron (>) bo'lgan o'lchov strelkasi (SVG marker uslubida).
void _drawArrow(Canvas canvas, Offset a, Offset b) {
  final paint = Paint()
    ..color = _kArrow
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(a, b, paint);
  final dir = (b - a) / (b - a).distance;
  const headLen = 6.0;
  const headHalf = 4.0;
  // b uchidagi chevron (tashqariga qaraydi)
  final n = Offset(-dir.dy, dir.dx); // normal
  canvas.drawLine(b - dir * headLen + n * headHalf, b, paint);
  canvas.drawLine(b - dir * headLen - n * headHalf, b, paint);
  // a uchidagi chevron
  canvas.drawLine(a + dir * headLen + n * headHalf, a, paint);
  canvas.drawLine(a + dir * headLen - n * headHalf, a, paint);
}

TextPainter _layoutText(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  return tp;
}

// Matnni markazi center bo'lib chizadi.
void _paintTextCentered(
    Canvas canvas, String text, Offset center, TextStyle style) {
  final tp = _layoutText(text, style);
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

Paint _fill(Color c) => Paint()..color = c;

Paint get _borderPaint => Paint()
  ..color = _kCakeBorder
  ..strokeWidth = 1
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round;

Paint get _cutPaint => Paint()
  ..color = _kCutLine
  ..strokeWidth = 0.8
  ..style = PaintingStyle.stroke;

Path _quad(Offset a, Offset b, Offset c, Offset d) => Path()
  ..moveTo(a.dx, a.dy)
  ..lineTo(b.dx, b.dy)
  ..lineTo(c.dx, c.dy)
  ..lineTo(d.dx, d.dy)
  ..close();

// ---- To'rtburchak (3D plita, kabinet proyeksiya) ----

class _RectSidePainter extends CustomPainter {
  final int widthCm;
  final int lengthCm;
  final int pieces;

  // Chuqurlik (orqaga ketish) birlik vektori: 1 sm ekranda shuncha
  // (masshtabdan keyin) o'ng-yuqoriga suriladi.
  static const double depthX = 0.55;
  static const double depthY = -0.35;

  static const double topPad = 20;
  static const double bottomPad = 36; // eni strelkasi + «30 sm»
  static const double leftPad = 16;
  static const double rightPad = 76; // uzunlik strelkasi + «50 sm»

  _RectSidePainter({
    required this.widthCm,
    required this.lengthCm,
    required this.pieces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final availW = size.width - leftPad - rightPad;
    final availH = size.height - topPad - bottomPad;
    if (availW <= 0 || availH <= 0) return;

    final hCm = _rectHeightCm(widthCm, lengthCm);
    // Masshtab: proyeksiya eni (W + dx·L) va bo'yi (h + |dy|·L) sig'sin.
    final s = math.min(
      availW / (widthCm + depthX * lengthCm),
      availH / (hCm - depthY * lengthCm),
    );
    final depth = Offset(depthX, depthY) * s; // 1 sm chuqurlik
    final w = widthCm * s;
    final h = hCm * s;
    final dTotal = depth * lengthCm.toDouble();

    // Markazlash: old-pastki chap burchakdan boshlaymiz.
    final totalW = w + dTotal.dx;
    final totalH = h - dTotal.dy;
    final x0 = leftPad + (availW - totalW) / 2;
    final yBottom = topPad + (availH - totalH) / 2 + totalH;

    final fbl = Offset(x0, yBottom); // old-past-chap
    final fbr = fbl + Offset(w, 0); // old-past-o'ng
    final ftl = fbl - Offset(0, h); // old-ust-chap (ust yuzaning old qirrasi)
    final ftr = fbr - Offset(0, h);
    final btl = ftl + dTotal; // orqa-ust-chap
    final btr = ftr + dTotal;
    final bbr = fbr + dTotal; // orqa-past-o'ng (yon yuza uchun)

    // Yuzalar: avval yon/old (quyuqroq), keyin ust (och) — chiziqlar ustida.
    final sidePath = _quad(fbr, bbr, btr, ftr);
    final frontPath = _quad(fbl, fbr, ftr, ftl);
    final topPath = _quad(ftl, ftr, btr, btl);
    canvas.drawPath(sidePath, _fill(_kCakeSide));
    canvas.drawPath(frontPath, _fill(_kCakeFront));
    canvas.drawPath(topPath, _fill(_kCakeTop));

    // To'r: bo'lak kvadratga eng yaqin bo'ladigan ustun×qator.
    final (cols, rows) = _bestGrid(pieces, widthCm, lengthCm);
    final cellW = w / cols; // ekran px (eni bo'ylab)
    final rowCm = lengthCm / rows; // sm (chuqurlik bo'ylab)

    // Ustun kesiklari: ust yuzada orqaga, old yuzada pastga davom etadi.
    for (int i = 1; i < cols; i++) {
      final t = ftl + Offset(cellW * i, 0);
      _drawDashedLine(canvas, t, t + dTotal, _cutPaint);
      _drawDashedLine(canvas, t, fbl + Offset(cellW * i, 0), _cutPaint);
    }
    // Qator kesiklari: ust yuzada eni bo'ylab, yon yuzada pastga davom etadi.
    for (int j = 1; j < rows; j++) {
      final off = depth * (rowCm * j);
      _drawDashedLine(canvas, ftl + off, ftr + off, _cutPaint);
      _drawDashedLine(canvas, ftr + off, fbr + off, _cutPaint);
    }

    // Yuzalar konturi (kesish chiziqlari ustidan toza ramka).
    canvas.drawPath(topPath, _borderPaint);
    canvas.drawPath(frontPath, _borderPaint);
    canvas.drawPath(sidePath, _borderPaint);

    // Bo'lak raqamlari ust yuzada (1 — orqa-chap, tepadan boshlanadi).
    final rowPx = -depth.dy * rowCm; // bir qatorning ekran balandligi
    if (pieces <= 60 && cellW >= 16 && rowPx >= 10) {
      for (int j = 0; j < rows; j++) {
        for (int i = 0; i < cols; i++) {
          final num = j * cols + i + 1;
          // j=0 orqa qator (ekranda tepada) — raqamlash yuqoridan boshlansin.
          final center = ftl +
              Offset(cellW * (i + 0.5), 0) +
              depth * (rowCm * (rows - j - 0.5));
          _paintTextCentered(canvas, '$num', center, _kNumberStyle);
        }
      }
    }

    // Eni strelkasi: old-pastki qirra ostida («30 sm»).
    final wArrowY = yBottom + 12;
    _drawArrow(canvas, Offset(fbl.dx, wArrowY), Offset(fbr.dx, wArrowY));
    final wLabel = _layoutText('$widthCm sm', _kLabelStyle);
    wLabel.paint(
        canvas, Offset(fbl.dx + w / 2 - wLabel.width / 2, wArrowY + 5));

    // Uzunlik strelkasi: o'ng yon qirraga parallel («50 sm»).
    final dDir = dTotal / dTotal.distance;
    final dNorm = Offset(-dDir.dy, dDir.dx); // tashqariga (o'ng-past)
    final aStart = fbr + dNorm * 12;
    final aEnd = bbr + dNorm * 12;
    _drawArrow(canvas, aStart, aEnd);
    final lLabel = _layoutText('$lengthCm sm', _kLabelStyle);
    final lMid = (aStart + aEnd) / 2 + dNorm * 8;
    lLabel.paint(canvas, Offset(lMid.dx, lMid.dy - lLabel.height / 2));
  }

  @override
  bool shouldRepaint(_RectSidePainter old) =>
      old.widthCm != widthCm ||
      old.lengthCm != lengthCm ||
      old.pieces != pieces;
}

// ---- Dumaloq (3D silindr, teng sektorlar) ----

class _RoundSidePainter extends CustomPainter {
  final int diameterCm;
  final int pieces;

  static const double top = 36; // diametr strelkasi + yorliq
  static const double bottom = 10;

  _RoundSidePainter({required this.diameterCm, required this.pieces});

  @override
  void paint(Canvas canvas, Size size) {
    const side = 16.0;
    final availW = size.width - side * 2;
    final availH = size.height - top - bottom;
    if (availW <= 0 || availH <= 0) return;

    final hCm = _roundHeightCm(diameterCm);
    // Masshtab (px/sm): eni bo'yicha diametr, bo'yi bo'yicha ellips + devor.
    final p = math.min(
      availW / diameterCm,
      availH / (_kEllipseK * diameterCm + hCm),
    );
    final rx = diameterCm * p / 2;
    final ry = rx * _kEllipseK;
    final h = hCm * p;

    final cx = side + availW / 2;
    // Vertikal markazlash: ust ellips + devor.
    final blockH = 2 * ry + h;
    final cy = top + (availH - blockH) / 2 + ry;
    final center = Offset(cx, cy);
    final topOval =
        Rect.fromCenter(center: center, width: 2 * rx, height: 2 * ry);
    final bottomOval = Rect.fromCenter(
        center: Offset(cx, cy + h), width: 2 * rx, height: 2 * ry);

    // Yon devor: chap qirra → pastki ellips old yarmi → o'ng qirra.
    final wall = Path()
      ..moveTo(cx - rx, cy)
      ..lineTo(cx - rx, cy + h)
      ..arcTo(bottomOval, math.pi, -math.pi, false)
      ..lineTo(cx + rx, cy)
      ..arcTo(topOval, 0, math.pi, false)
      ..close();
    canvas.drawPath(wall, _fill(_kCakeSide));
    canvas.drawPath(wall, _borderPaint);

    // Ust yuza (ellips).
    canvas.drawOval(topOval, _fill(_kCakeTop));

    // Sektor kesish chiziqlari (markazdan chetgacha, punktir).
    final step = 2 * math.pi / pieces;
    const start = -math.pi / 2; // orqadan (ekranda tepadan) boshlanadi
    for (int i = 0; i < pieces; i++) {
      final a = start + step * i;
      final edge = center + Offset(math.cos(a) * rx, math.sin(a) * ry);
      _drawDashedLine(canvas, center, edge, _cutPaint);
      // Old yarim (sin a > 0) sektor chegaralari devorga ham tushadi.
      if (math.sin(a) > 0.05) {
        _drawDashedLine(canvas, edge, edge + Offset(0, h), _cutPaint);
      }
    }

    canvas.drawOval(topOval, _borderPaint);

    // Sektor raqamlari (ko'p bo'lsa chalkashmasin deb yozilmaydi).
    if (pieces <= 24) {
      for (int i = 0; i < pieces; i++) {
        final mid = start + step * (i + 0.5);
        final pos = center +
            Offset(math.cos(mid) * rx * 0.62, math.sin(mid) * ry * 0.62);
        _paintTextCentered(canvas, '${i + 1}', pos, _kNumberStyle);
      }
    }

    // Diametr strelkasi (ust ellips tepasida) + «⌀ 24 sm» yorlig'i.
    final arrowY = cy - ry - 12;
    _drawArrow(canvas, Offset(cx - rx, arrowY), Offset(cx + rx, arrowY));
    final label = _layoutText('⌀ $diameterCm sm', _kLabelStyle);
    label.paint(canvas, Offset(cx - label.width / 2, arrowY - 16));
  }

  @override
  bool shouldRepaint(_RoundSidePainter old) =>
      old.diameterCm != diameterCm || old.pieces != pieces;
}
