import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Position is shown with an arrow; all cards keep a quiet continuous outline.
class PositionBorder extends RoundedRectangleBorder {
  const PositionBorder({
    this.pinned = false,
    this.bottom = false,
    this.radius = 16,
  }) : super(side: const BorderSide(color: AppColors.divider));
  final bool pinned;
  final bool bottom;
  final double radius;
  @override
  BorderRadiusGeometry get borderRadius => BorderRadius.circular(radius);
  @override
  RoundedRectangleBorder scale(double t) =>
      PositionBorder(pinned: pinned, bottom: bottom, radius: radius * t);
}
