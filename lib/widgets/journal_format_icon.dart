import 'package:flutter/material.dart';

enum JournalFormatSymbol { strike, divider }

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
    if (symbol == JournalFormatSymbol.strike) {
      final text = TextPainter(
        text: TextSpan(
          text: 'ab',
          style: TextStyle(color: color, fontSize: 21, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
      );
      canvas.drawLine(const Offset(1, 13), const Offset(23, 13), paint);
    } else {
      canvas.drawLine(
        const Offset(4, 5),
        const Offset(20, 5),
        paint..color = color.withValues(alpha: .5),
      );
      canvas.drawLine(const Offset(4, 19), const Offset(20, 19), paint);
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
