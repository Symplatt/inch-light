import 'package:flutter/material.dart';

enum JournalActionSymbol {
  export,
  exportAll,
  folder,
  restore,
  undo,
  redo,
  done,
  tags,
  share,
  saveImage,
}

class JournalExportIcon extends StatelessWidget {
  const JournalExportIcon({super.key, this.multiple = false});
  final bool multiple;
  @override
  Widget build(BuildContext context) => JournalActionIcon(
    multiple ? JournalActionSymbol.exportAll : JournalActionSymbol.export,
  );
}

/// Each action occupies the same 24px box with an 18px painted height.
class JournalActionIcon extends StatelessWidget {
  const JournalActionIcon(this.symbol, {super.key});
  final JournalActionSymbol symbol;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: CustomPaint(
      painter: _ActionPainter(
        symbol,
        IconTheme.of(context).color ?? Colors.black,
      ),
    ),
  );
}

class _ActionPainter extends CustomPainter {
  const _ActionPainter(this.symbol, this.color);
  final JournalActionSymbol symbol;
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
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), pen);
    if (symbol == JournalActionSymbol.export ||
        symbol == JournalActionSymbol.exportAll) {
      final multiple = symbol == JournalActionSymbol.exportAll;
      canvas.drawPath(
        Path()
          ..moveTo(3, 10)
          ..lineTo(3, 21)
          ..lineTo(21, 21)
          ..lineTo(21, 10),
        pen,
      );
      line(12, multiple ? 10 : 16, 12, 3);
      canvas.drawPath(
        Path()
          ..moveTo(8, 7)
          ..lineTo(12, 3)
          ..lineTo(16, 7),
        pen,
      );
      if (multiple) {
        line(9, 13, 15, 13);
        line(7, 17, 17, 17);
      }
    } else if (symbol == JournalActionSymbol.share) {
      line(7.7, 10.8, 16.3, 6.2);
      line(7.7, 13.2, 16.3, 17.8);
      for (final center in [
        const Offset(5.5, 12),
        const Offset(18.5, 5.5),
        const Offset(18.5, 18.5),
      ]) {
        canvas.drawCircle(center, 2.5, pen);
      }
    } else if (symbol == JournalActionSymbol.saveImage) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 14)
          ..lineTo(3, 21)
          ..lineTo(21, 21)
          ..lineTo(21, 14),
        pen,
      );
      line(12, 3, 12, 15);
      canvas.drawPath(
        Path()
          ..moveTo(7, 10)
          ..lineTo(12, 15)
          ..lineTo(17, 10),
        pen,
      );
    } else if (symbol == JournalActionSymbol.folder) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 6)
          ..quadraticBezierTo(3, 3, 5, 3)
          ..lineTo(9, 3)
          ..lineTo(12, 6)
          ..lineTo(19, 6)
          ..quadraticBezierTo(21, 6, 21, 8)
          ..lineTo(21, 19)
          ..quadraticBezierTo(21, 21, 19, 21)
          ..lineTo(5, 21)
          ..quadraticBezierTo(3, 21, 3, 19)
          ..close(),
        pen,
      );
      line(10, 13.5, 16, 13.5);
      line(13, 10.5, 13, 16.5);
    } else if (symbol == JournalActionSymbol.tags) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 4)
          ..lineTo(11, 3)
          ..lineTo(21, 13)
          ..lineTo(13, 21)
          ..lineTo(3, 11)
          ..close(),
        pen,
      );
      canvas.drawCircle(const Offset(7.5, 7.5), 1.2, pen);
    } else if (symbol == JournalActionSymbol.done) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 12)
          ..lineTo(9, 21)
          ..lineTo(21, 3),
        pen,
      );
    } else {
      if (symbol == JournalActionSymbol.redo) {
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawPath(
        Path()
          ..moveTo(3, 10)
          ..cubicTo(4, 6, 7, 3, 12, 3)
          ..cubicTo(17, 3, 21, 7, 21, 12)
          ..cubicTo(21, 17, 17, 21, 12, 21)
          ..cubicTo(8.5, 21, 5.5, 19, 4, 16),
        pen,
      );
      canvas.drawPath(
        Path()
          ..moveTo(3, 3)
          ..lineTo(3, 10)
          ..lineTo(10, 10),
        pen,
      );
      if (symbol == JournalActionSymbol.restore) {
        line(12, 8, 12, 13);
        line(12, 13, 16, 13);
      }
    }
  }

  @override
  bool shouldRepaint(_ActionPainter old) =>
      old.symbol != symbol || old.color != color;
}
