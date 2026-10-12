import 'dart:ui' show ClipOp;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The same position cue is used for records and to-do items.
class PositionBorder extends ShapeBorder {
  const PositionBorder({
    this.pinned = false,
    this.bottom = false,
    this.radius = 16,
  });
  final bool pinned;
  final bool bottom;
  final double radius;

  Color get color => pinned ? const Color(0xFFBEC2C8) : AppColors.divider;
  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(1);
  @override
  ShapeBorder scale(double t) =>
      PositionBorder(pinned: pinned, bottom: bottom, radius: radius * t);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(1));
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final r = rect.deflate(.5);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = RRect.fromRectAndRadius(r, Radius.circular(radius));
    if (!bottom) {
      canvas.drawRRect(outline, paint);
      return;
    }
    // Keep each corner and 10% at either end solid, dash the middle 80%.
    final horizontalStart = (r.width * .1).clamp(radius, r.width / 2);
    final verticalStart = (r.height * .1).clamp(radius, r.height / 2);
    final cuts = [
      Rect.fromLTRB(
        r.left + horizontalStart,
        r.top - 1,
        r.right - horizontalStart,
        r.top + 1,
      ),
      Rect.fromLTRB(
        r.left + horizontalStart,
        r.bottom - 1,
        r.right - horizontalStart,
        r.bottom + 1,
      ),
      Rect.fromLTRB(
        r.left - 1,
        r.top + verticalStart,
        r.left + 1,
        r.bottom - verticalStart,
      ),
      Rect.fromLTRB(
        r.right - 1,
        r.top + verticalStart,
        r.right + 1,
        r.bottom - verticalStart,
      ),
    ];
    canvas.save();
    for (final cut in cuts) {
      canvas.clipRect(cut, clipOp: ClipOp.difference);
    }
    canvas.drawRRect(outline, paint);
    canvas.restore();
    void dash(Offset a, Offset b) {
      final length = (b - a).distance;
      if (length <= 0) return;
      final direction = (b - a) / length;
      for (double i = 0; i < length; i += 8) {
        canvas.drawLine(
          a + direction * i,
          a + direction * (i + 4).clamp(0, length),
          paint,
        );
      }
    }

    dash(Offset(cuts[0].left, r.top), Offset(cuts[0].right, r.top));
    dash(Offset(cuts[1].left, r.bottom), Offset(cuts[1].right, r.bottom));
    dash(Offset(r.left, cuts[2].top), Offset(r.left, cuts[2].bottom));
    dash(Offset(r.right, cuts[3].top), Offset(r.right, cuts[3].bottom));
  }
}
