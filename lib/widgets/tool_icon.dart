import 'package:flutter/material.dart';

const _grayscale = ColorFilter.matrix([
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class ToolIcon extends StatelessWidget {
  const ToolIcon({super.key, required this.meal, this.toolId});
  final bool meal;
  final String? toolId;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 44,
      child: toolId == 'academic_peers'
          ? const CustomPaint(painter: _AcademicPeersIconPainter())
          : toolId == 'project_updates'
          ? ColorFiltered(
              colorFilter: _grayscale,
              child: Image.asset(
                'assets/project_updates_reference.png',
                fit: BoxFit.contain,
              ),
            )
          : toolId == 'last_time'
          ? const CustomPaint(painter: _LastTimeIconPainter())
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
                        child: ColorFiltered(
                          colorFilter: _grayscale,
                          child: Image.asset('assets/work_log_reference.png'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

class _AcademicPeersIconPainter extends CustomPainter {
  const _AcademicPeersIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44, size.height / 44);
    final outline = Paint()
      ..color = const Color(0xFF454545)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final tint = Paint()..color = const Color(0xFFE9E9E9);
    for (final head in [
      const Offset(10, 17),
      const Offset(22, 12),
      const Offset(34, 17),
    ]) {
      canvas.drawCircle(head, 3.8, tint);
      canvas.drawCircle(head, 3.8, outline);
    }
    canvas.drawPath(
      Path()
        ..moveTo(15, 22)
        ..quadraticBezierTo(22, 15, 29, 22),
      outline,
    );
    final book = Path()
      ..moveTo(5, 24)
      ..quadraticBezierTo(14, 22, 22, 28)
      ..quadraticBezierTo(30, 22, 39, 24)
      ..lineTo(39, 34)
      ..quadraticBezierTo(30, 33, 22, 38)
      ..quadraticBezierTo(14, 33, 5, 34)
      ..close();
    canvas.drawPath(book, tint);
    canvas.drawPath(book, outline);
    canvas.drawLine(const Offset(22, 28), const Offset(22, 38), outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AcademicPeersIconPainter oldDelegate) => false;
}

class _LastTimeIconPainter extends CustomPainter {
  const _LastTimeIconPainter();

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
    canvas.drawCircle(const Offset(22, 23), 1.5, Paint()..color = ink.color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LastTimeIconPainter oldDelegate) => false;
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
