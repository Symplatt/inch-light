import 'package:flutter/material.dart';

class ToolIcon extends StatelessWidget {
  const ToolIcon({super.key, required this.meal, this.toolId});
  final bool meal;
  final String? toolId;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 44,
      child: toolId == 'academic_peers'
          ? ClipOval(
              child: Stack(
                children: [
                  Positioned(
                    // Clip just inside the supplied circle so only its portrait is shown.
                    left: -77 * 44 / 1100,
                    top: -77 * 44 / 1100,
                    width: 1254 * 44 / 1100,
                    height: 1254 * 44 / 1100,
                    child: Image.asset('assets/academic_peers_reference.png'),
                  ),
                ],
              ),
            )
          : const {'project_updates', 'last_time'}.contains(toolId)
          ? CustomPaint(painter: _NewToolIconPainter(toolId!))
          : meal
          ? CustomPaint(painter: _ToolIconPainter(meal))
          : Center(
              child: ClipRect(
                child: SizedBox(
                  width: 44,
                  height: 38,
                  // Crop the supplied artwork at display time to omit its frame.
                  child: Stack(
                    children: [
                      Positioned(
                        left: -160 * 44 / 950,
                        top: -250 * 44 / 950,
                        width: 1254 * 44 / 950,
                        height: 1254 * 44 / 950,
                        child: Image.asset('assets/work_log_reference.png'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

class _NewToolIconPainter extends CustomPainter {
  const _NewToolIconPainter(this.toolId);
  final String toolId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44, size.height / 44);
    final ink = Paint()
      ..color = const Color(0xFF454545)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (toolId) {
      case 'project_updates':
        // The face turns toward the hand behind the hip.
        canvas.drawPath(
          Path()
            ..moveTo(20, 15)
            ..cubicTo(12, 16, 10, 8, 15, 5)
            ..cubicTo(19, 2, 24, 5, 24, 9)
            ..lineTo(27, 11)
            ..lineTo(24, 12)
            ..quadraticBezierTo(24, 16, 20, 15)
            ..lineTo(19, 19),
          ink,
        );
        canvas.drawCircle(const Offset(22, 9), .7, Paint()..color = ink.color);
        canvas.drawPath(
          Path()
            ..moveTo(17, 17)
            ..quadraticBezierTo(11, 22, 12, 30)
            ..lineTo(9, 39)
            ..lineTo(14, 40)
            ..moveTo(12, 29)
            ..quadraticBezierTo(20, 27, 22, 32)
            ..lineTo(26, 39)
            ..lineTo(31, 39)
            ..moveTo(21, 18)
            ..quadraticBezierTo(27, 19, 29, 24)
            ..quadraticBezierTo(31, 29, 25, 30)
            ..lineTo(22, 28)
            ..moveTo(21, 20)
            ..lineTo(23, 25)
            ..lineTo(20, 29)
            ..moveTo(16, 21)
            ..lineTo(9, 24)
            ..lineTo(7, 30)
            ..moveTo(31, 28)
            ..lineTo(34, 27)
            ..moveTo(32, 32)
            ..lineTo(35, 33),
          ink,
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(9, 14)
            ..cubicTo(13, 4, 27, 3, 34, 13)
            ..cubicTo(43, 27, 29, 42, 15, 35)
            ..quadraticBezierTo(7, 31, 7, 23)
            ..moveTo(5, 10)
            ..lineTo(8, 17)
            ..lineTo(15, 14)
            ..moveTo(22, 12)
            ..lineTo(22, 23)
            ..lineTo(29, 27),
          ink,
        );
        canvas.drawCircle(
          const Offset(22, 23),
          1.5,
          Paint()..color = ink.color,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NewToolIconPainter oldDelegate) =>
      toolId != oldDelegate.toolId;
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
