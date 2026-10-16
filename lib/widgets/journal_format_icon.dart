import 'package:flutter/material.dart';

enum JournalFormatSymbol {
  h1,
  h2,
  h3,
  bold,
  italic,
  strike,
  divider,
  bullet,
  underline,
  highlight,
  superscript,
  subscript,
  code,
  table,
  alignLeft,
  alignCenter,
  alignRight,
}

class JournalFormatIcon extends StatelessWidget {
  const JournalFormatIcon(this.symbol, {super.key});
  final JournalFormatSymbol symbol;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: CustomPaint(
      painter: _FormatPainter(
        symbol,
        IconTheme.of(context).color ?? const Color(0xFF252525),
      ),
    ),
  );
}

class _FormatPainter extends CustomPainter {
  const _FormatPainter(this.symbol, this.color);
  final JournalFormatSymbol symbol;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    // Draw letter icons on the same 24-pixel grid as Material icons. Using
    // Text widgets here makes their visible baseline depend on the phone font.
    canvas.scale(size.width / 24, size.height / 24);
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    void path(Path value) =>
        canvas.drawPath(value, paint..style = PaintingStyle.stroke);
    if ([
      JournalFormatSymbol.h1,
      JournalFormatSymbol.h2,
      JournalFormatSymbol.h3,
    ].contains(symbol)) {
      line(2, 4, 2, 20);
      line(12, 4, 12, 20);
      line(2, 12, 12, 12);
      paint.strokeWidth = 1.5;
      switch (symbol) {
        case JournalFormatSymbol.h1:
          line(17, 15, 19, 13);
          line(19, 13, 19, 20);
          line(17, 20, 21, 20);
        case JournalFormatSymbol.h2:
          path(
            Path()
              ..moveTo(16, 14.5)
              ..cubicTo(16.5, 11.5, 23, 12, 21, 15.5)
              ..lineTo(16, 20)
              ..lineTo(22, 20),
          );
        case JournalFormatSymbol.h3:
          path(
            Path()
              ..moveTo(16, 13.5)
              ..cubicTo(23, 10.5, 23, 17, 18, 16.5)
              ..cubicTo(23, 16, 23, 22, 16, 19.5),
          );
        default:
          break;
      }
    } else if (symbol == JournalFormatSymbol.bold) {
      paint.strokeWidth = 2.7;
      path(
        Path()
          ..moveTo(7, 4)
          ..lineTo(12, 4)
          ..cubicTo(19, 4, 19, 12, 12, 12)
          ..lineTo(7, 12)
          ..moveTo(12, 12)
          ..cubicTo(20, 12, 20, 20, 12, 20)
          ..lineTo(7, 20)
          ..moveTo(7, 4)
          ..lineTo(7, 20),
      );
    } else if (symbol == JournalFormatSymbol.italic) {
      line(10, 4, 19, 4);
      line(5, 20, 14, 20);
      line(15, 4, 9, 20);
    } else if (symbol == JournalFormatSymbol.strike) {
      path(
        Path()
          ..moveTo(18, 4)
          ..lineTo(10, 4)
          ..cubicTo(3, 4, 3, 12, 12, 12)
          ..cubicTo(21, 12, 21, 20, 14, 20)
          ..lineTo(6, 20),
      );
      line(3, 12, 21, 12);
    } else if (symbol == JournalFormatSymbol.underline) {
      path(
        Path()
          ..moveTo(6, 4)
          ..lineTo(6, 11)
          ..cubicTo(6, 18, 18, 18, 18, 11)
          ..lineTo(18, 4),
      );
      line(4, 20, 20, 20);
    } else if (symbol == JournalFormatSymbol.highlight) {
      // Slanted marker tip above a color swatch, on the same grid as text icons.
      path(
        Path()
          ..moveTo(6, 13)
          ..lineTo(15, 4)
          ..lineTo(20, 9)
          ..lineTo(11, 18)
          ..close(),
      );
      line(8, 15, 5, 18);
      line(4, 20, 20, 20);
    } else if (symbol == JournalFormatSymbol.bullet) {
      for (final y in [5.0, 12.0, 19.0]) {
        canvas.drawCircle(Offset(4, y), 1.8, paint..style = PaintingStyle.fill);
        line(9, y, 21, y);
      }
    } else if (symbol == JournalFormatSymbol.superscript ||
        symbol == JournalFormatSymbol.subscript) {
      final superscript = symbol == JournalFormatSymbol.superscript;
      final top = superscript ? 8.0 : 4.0;
      final bottom = superscript ? 20.0 : 16.0;
      line(3, top, 12, bottom);
      line(12, top, 3, bottom);
      final y = superscript ? 4.0 : 12.0;
      path(
        Path()
          ..moveTo(16, y)
          ..lineTo(21, y)
          ..lineTo(21, y + 3)
          ..lineTo(16, y + 8)
          ..lineTo(22, y + 8),
      );
    } else if (symbol == JournalFormatSymbol.code) {
      path(
        Path()
          ..moveTo(8, 4)
          ..lineTo(2, 12)
          ..lineTo(8, 20),
      );
      path(
        Path()
          ..moveTo(16, 4)
          ..lineTo(22, 12)
          ..lineTo(16, 20),
      );
    } else if (symbol == JournalFormatSymbol.table) {
      path(Path()..addRect(const Rect.fromLTRB(3, 4, 21, 20)));
      line(3, 10, 21, 10);
      line(3, 15, 21, 15);
      line(9, 4, 9, 20);
      line(15, 4, 15, 20);
    } else if ([
      JournalFormatSymbol.alignLeft,
      JournalFormatSymbol.alignCenter,
      JournalFormatSymbol.alignRight,
    ].contains(symbol)) {
      for (var i = 0; i < 4; i++) {
        final short = i.isOdd;
        final left = !short || symbol == JournalFormatSymbol.alignLeft
            ? 3.0
            : symbol == JournalFormatSymbol.alignCenter
            ? 6.0
            : 9.0;
        final right = !short || symbol == JournalFormatSymbol.alignRight
            ? 21.0
            : symbol == JournalFormatSymbol.alignCenter
            ? 18.0
            : 15.0;
        line(left, 4 + i * 16 / 3, right, 4 + i * 16 / 3);
      }
    } else {
      canvas.drawLine(
        const Offset(4, 4),
        const Offset(20, 4),
        paint..color = color.withValues(alpha: .5),
      );
      canvas.drawLine(const Offset(4, 20), const Offset(20, 20), paint);
      canvas.drawLine(
        const Offset(1, 12),
        const Offset(23, 12),
        paint
          ..color = color
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_FormatPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}
