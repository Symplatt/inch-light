import 'package:flutter/material.dart';

class AppColors {
  // 主色调：黑色与低饱和玫瑰粉
  static const Color primary = Color(0xFF171717);
  static const Color accent = Color(0xFFB99DA7);

  // 背景色
  static const Color bg = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;

  // 文本颜色
  static const Color textDark = Color(0xFF252525);
  static const Color textGrey = Color(0xFF60636A);

  // 功能色
  static const Color success = Color(0xFF84978A);
  static const Color warning = Color(0xFFE6A23C);
  static const Color danger = Color(0xFFB28E91);

  static const Color divider = Color(0xFFEBEDF1);

  // 阴影样式
  static List<BoxShadow> get shadow => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.05),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
}
