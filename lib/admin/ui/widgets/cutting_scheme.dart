// admin/ui/widgets/cutting_scheme.dart — «Kesish sxemasi» diagrammasi:
// CuttingSchemeView — tex kartadagi shakl (round/rect) va partiya (Штук) dan
// tortni bo'laklarga kesish sxemasini chizadi (CustomPaint). To'rtburchak
// uchun bo'lak kvadratga eng yaqin bo'ladigan ustun×qator to'ri, dumaloq
// uchun teng sektorlar. Ko'rinish tort_30x50_10_bolak_kesish_sxemasi.svg
// namunasiga mos: tort rang FAEEDA, jigarrang ramka, punktir kesish
// chiziqlari, bo'lak raqamlari, kulrang o'lchov strelkalari.
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---- Namuna SVG'dagi ranglar ----
const Color _kCakeFill = Color(0xFFFAEEDA);
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

// Kesish sxemasi vidjeti. Mavjud kenglikka moslashadi (balandlik shakl
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

  bool get _isRect => shape == 'rect' && (widthCm ?? 0) > 0 && (lengthCm ?? 0) > 0;

  bool get _isRound => shape == 'round' && (diameterCm ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    if ((!_isRect && !_isRound) || pieces < 2) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final CustomPainter painter = _isRect
            ? _RectSchemePainter(
                widthCm: widthCm!,
                lengthCm: lengthCm!,
                pieces: pieces,
              )
            : _RoundSchemePainter(diameterCm: diameterCm!, pieces: pieces);
        // Balandlik: tort maydoni + strelka/izoh joylari (moslashuvchan).
        final double height;
        if (_isRect) {
          final cakeW = math.max(
              60.0, maxW - _SchemeLayout.leftRect - _SchemeLayout.rightRect);
          height = (_SchemeLayout.top +
                  _SchemeLayout.bottom +
                  cakeW * (lengthCm! / widthCm!))
              .clamp(220.0, 460.0);
        } else {
          final d = math.max(
              60.0, maxW - _SchemeLayout.leftRound - _SchemeLayout.rightRound);
          height =
              (_SchemeLayout.top + _SchemeLayout.bottom + d).clamp(220.0, 420.0);
        }
        return SizedBox(
          width: double.infinity,
          height: height,
          child: CustomPaint(painter: painter),
        );
      },
    );
  }
}

// Chekka joylar (strelka, yorliq, yon izoh, pastki izoh uchun).
class _SchemeLayout {
  static const double top = 36; // yuqori strelka + «30 sm» yorlig'i
  static const double bottom = 26; // pastki «Punktir chiziqlar...» izohi
  static const double leftRect = 58; // chap strelka + «50 sm» yorlig'i
  static const double rightRect = 92; // «Har bo'lak ...» yon izohi
  static const double leftRound = 16;
  static const double rightRound = 16;
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

// Pastki izoh: «Punktir chiziqlar — kesish joylari».
void _paintFooter(Canvas canvas, Size size) {
  _paintTextCentered(
    canvas,
    'Punktir chiziqlar — kesish joylari',
    Offset(size.width / 2, size.height - _SchemeLayout.bottom / 2),
    _kLabelStyle,
  );
}

Paint get _cakeFillPaint => Paint()..color = _kCakeFill;

Paint get _cakeBorderPaint => Paint()
  ..color = _kCakeBorder
  ..strokeWidth = 1
  ..style = PaintingStyle.stroke;

Paint get _cutPaint => Paint()
  ..color = _kCutLine
  ..strokeWidth = 0.8
  ..style = PaintingStyle.stroke;

// ---- To'rtburchak sxema ----

class _RectSchemePainter extends CustomPainter {
  final int widthCm;
  final int lengthCm;
  final int pieces;

  _RectSchemePainter({
    required this.widthCm,
    required this.lengthCm,
    required this.pieces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final availW = size.width - _SchemeLayout.leftRect - _SchemeLayout.rightRect;
    final availH = size.height - _SchemeLayout.top - _SchemeLayout.bottom;
    if (availW <= 0 || availH <= 0) return;

    // Tortni mavjud maydonga masshtablab joylashtiramiz (nisbat saqlanadi).
    final scale = math.min(availW / widthCm, availH / lengthCm);
    final cakeW = widthCm * scale;
    final cakeH = lengthCm * scale;
    final left = _SchemeLayout.leftRect + (availW - cakeW) / 2;
    final top = _SchemeLayout.top + (availH - cakeH) / 2;
    final rect = Rect.fromLTWH(left, top, cakeW, cakeH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(rrect, _cakeFillPaint);
    canvas.drawRRect(rrect, _cakeBorderPaint);

    // To'r: bo'lak kvadratga eng yaqin bo'ladigan ustun×qator.
    final (cols, rows) = _bestGrid(pieces, widthCm, lengthCm);
    final cellW = cakeW / cols;
    final cellH = cakeH / rows;

    // Punktir kesish chiziqlari.
    for (int i = 1; i < cols; i++) {
      final x = left + cellW * i;
      _drawDashedLine(canvas, Offset(x, top), Offset(x, top + cakeH), _cutPaint);
    }
    for (int j = 1; j < rows; j++) {
      final y = top + cellH * j;
      _drawDashedLine(
          canvas, Offset(left, y), Offset(left + cakeW, y), _cutPaint);
    }

    // Bo'lak raqamlari (qator bo'ylab). Katak juda kichik bo'lsa yozmaymiz.
    if (pieces <= 60 && cellW >= 16 && cellH >= 14) {
      for (int j = 0; j < rows; j++) {
        for (int i = 0; i < cols; i++) {
          final num = j * cols + i + 1;
          _paintTextCentered(
            canvas,
            '$num',
            Offset(left + cellW * (i + 0.5), top + cellH * (j + 0.5)),
            _kNumberStyle,
          );
        }
      }
    }

    // Yuqori o'lchov strelkasi: eni («30 sm»).
    final topArrowY = top - 12;
    _drawArrow(canvas, Offset(left, topArrowY), Offset(left + cakeW, topArrowY));
    final wLabel = _layoutText('$widthCm sm', _kLabelStyle);
    wLabel.paint(
        canvas, Offset(left + cakeW / 2 - wLabel.width / 2, topArrowY - 16));

    // Chap o'lchov strelkasi: uzunligi («50 sm»).
    final leftArrowX = left - 14;
    _drawArrow(canvas, Offset(leftArrowX, top), Offset(leftArrowX, top + cakeH));
    final lLabel = _layoutText('$lengthCm sm', _kLabelStyle);
    lLabel.paint(
      canvas,
      Offset(leftArrowX - 6 - lLabel.width, top + cakeH / 2 - lLabel.height / 2),
    );

    // Yon izoh: «Har bo'lak 15 × 10 sm».
    final pieceW = widthCm / cols;
    final pieceH = lengthCm / rows;
    final note1 = _layoutText("Har bo'lak", _kLabelStyle);
    final note2 =
        _layoutText('${_fmtCm(pieceW)} × ${_fmtCm(pieceH)} sm', _kLabelStyle);
    final noteX = left + cakeW + 10;
    final noteY = top + cakeH / 2 - (note1.height + note2.height + 4) / 2;
    note1.paint(canvas, Offset(noteX, noteY));
    note2.paint(canvas, Offset(noteX, noteY + note1.height + 4));

    _paintFooter(canvas, size);
  }

  @override
  bool shouldRepaint(_RectSchemePainter old) =>
      old.widthCm != widthCm ||
      old.lengthCm != lengthCm ||
      old.pieces != pieces;
}

// ---- Dumaloq sxema (teng sektorlar) ----

class _RoundSchemePainter extends CustomPainter {
  final int diameterCm;
  final int pieces;

  _RoundSchemePainter({required this.diameterCm, required this.pieces});

  @override
  void paint(Canvas canvas, Size size) {
    final availW =
        size.width - _SchemeLayout.leftRound - _SchemeLayout.rightRound;
    final availH = size.height - _SchemeLayout.top - _SchemeLayout.bottom;
    if (availW <= 0 || availH <= 0) return;

    final r = math.min(availW, availH) / 2;
    final center = Offset(
      _SchemeLayout.leftRound + availW / 2,
      _SchemeLayout.top + availH / 2,
    );

    canvas.drawCircle(center, r, _cakeFillPaint);
    canvas.drawCircle(center, r, _cakeBorderPaint);

    // Sektor kesish chiziqlari (markazdan chetgacha, punktir).
    final step = 2 * math.pi / pieces;
    const start = -math.pi / 2; // yuqoridan boshlanadi
    for (int i = 0; i < pieces; i++) {
      final a = start + step * i;
      final edge = center + Offset(math.cos(a), math.sin(a)) * r;
      _drawDashedLine(canvas, center, edge, _cutPaint);
    }

    // Sektor raqamlari (ko'p bo'lsa chalkashmasin deb yozilmaydi).
    if (pieces <= 24) {
      for (int i = 0; i < pieces; i++) {
        final mid = start + step * (i + 0.5);
        final pos = center + Offset(math.cos(mid), math.sin(mid)) * (r * 0.62);
        _paintTextCentered(canvas, '${i + 1}', pos, _kNumberStyle);
      }
    }

    // Diametr strelkasi (aylana ustida) + «⌀ 24 sm» yorlig'i.
    final arrowY = center.dy - r - 12;
    _drawArrow(
        canvas, Offset(center.dx - r, arrowY), Offset(center.dx + r, arrowY));
    final label = _layoutText('⌀ $diameterCm sm', _kLabelStyle);
    label.paint(canvas, Offset(center.dx - label.width / 2, arrowY - 16));

    _paintFooter(canvas, size);
  }

  @override
  bool shouldRepaint(_RoundSchemePainter old) =>
      old.diameterCm != diameterCm || old.pieces != pieces;
}
