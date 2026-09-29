import 'package:flutter/material.dart';

class AppColors {
  // 主色调：柔和蓝灰与玫瑰粉
  static const Color primary = Color(0xFF74798A);
  static const Color accent = Color(0xFFC18B9B);

  // 背景色
  static const Color bg = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;

  // 文本颜色
  static const Color textDark = Color(0xFF60646D);
  static const Color textGrey = Color(0xFF7B808B);

  // 功能色
  static const Color success = Color(0xFF748B7B);
  static const Color warning = Color(0xFFE6A23C);
  static const Color danger = Color(0xFFB67C80);

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
