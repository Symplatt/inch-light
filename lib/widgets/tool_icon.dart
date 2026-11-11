import 'package:flutter/material.dart';

class ToolIcon extends StatelessWidget {
  const ToolIcon({super.key, required this.meal});
  final bool meal;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 44,
      child: CustomPaint(painter: _ToolIconPainter(meal)),
    ),
  );
}

class _ToolIconPainter extends CustomPainter {
  const _ToolIconPainter(this.meal);
  final bool meal;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44, size.height / 44);
    if (meal) {
      // Uneven scale and rotation retain the brush face at a small icon size.
      void word(String text, Offset at, double fontSize, double angle) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(angle);
        for (final stroke in [true, false]) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'MealBrush',
                fontSize: fontSize,
                height: 1,
                foreground: Paint()
                  ..color = const Color(0xFF353535)
                  ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
                  ..strokeWidth = 0.8,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          painter.paint(canvas, Offset.zero);
          painter.dispose();
        }
        canvas.restore();
      }

      word('是啊', const Offset(3, 2), 12, -0.12);
      word('吃', const Offset(1, 15), 25, -0.15);
      word('什', const Offset(25, 9), 18, 0.10);
      word('么', const Offset(25, 28), 17, -0.12);
    } else {
      final ink = Paint()
        ..color = const Color(0xFF454545)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(9, 6, 25, 32),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFEEEEEE),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 5, 25, 32),
          const Radius.circular(4),
        ),
        ink,
      );
      canvas.drawLine(const Offset(14, 6), const Offset(14, 36), ink);
      canvas.drawLine(const Offset(19, 13), const Offset(27, 13), ink);
      canvas.drawLine(const Offset(19, 19), const Offset(25, 19), ink);
      canvas.drawLine(const Offset(5, 13), const Offset(10, 13), ink);
      canvas.drawLine(const Offset(5, 22), const Offset(10, 22), ink);
      canvas.drawLine(const Offset(5, 30), const Offset(10, 30), ink);
      final pencil = Path()
        ..moveTo(24, 32)
        ..lineTo(26, 25)
        ..lineTo(37, 14)
        ..lineTo(41, 18)
        ..lineTo(30, 29)
        ..close();
      canvas.drawPath(pencil, Paint()..color = Colors.white);
      canvas.drawPath(pencil, ink);
      canvas.drawLine(const Offset(34, 17), const Offset(38, 21), ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ToolIconPainter oldDelegate) =>
      meal != oldDelegate.meal;
}
