import 'package:flutter/material.dart';

class JournalExportIcon extends StatelessWidget {
  const JournalExportIcon({super.key, this.multiple = false});
  final bool multiple;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: CustomPaint(
      painter: _ExportPainter(
        multiple,
        IconTheme.of(context).color ?? Colors.black,
      ),
    ),
  );
}

class _ExportPainter extends CustomPainter {
  const _ExportPainter(this.multiple, this.color);
  final bool multiple;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(7, 10)
        ..lineTo(7, 21)
        ..lineTo(21, 21)
        ..lineTo(21, 10)
        ..moveTo(14, 14)
        ..lineTo(14, 3)
        ..moveTo(10, 7)
        ..lineTo(14, 3)
        ..lineTo(18, 7),
      pen,
    );
    if (multiple) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 7)
          ..lineTo(3, 17)
          ..lineTo(4, 17),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_ExportPainter old) =>
      old.multiple != multiple || old.color != color;
}
