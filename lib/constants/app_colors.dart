import 'package:flutter/material.dart';

class AppColors {
  // 主色调：深海蓝与活力橙
  static const Color primary = Color(0xFF2B2E4A);
  static const Color accent = Color(0xFFE84545);

  // 背景色
  static const Color bg = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;

  // 文本颜色
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF909399);

  // 功能色
  static const Color success = Color(0xFF67C23A);
  static const Color warning = Color(0xFFE6A23C);
  static const Color danger = Color(0xFFF56C6C);

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

// 【关键修复】定义在类外面的顶层变量，这样 TimerPage 就能直接用 taskColors[...] 了
const List<Color> taskColors = [
  Color(0xFFFF5252), // 热情红
  Color(0xFFFFB74D), // 活力橙
  Color(0xFFFFD740), // 柠檬黄
  Color(0xFF69F0AE), // 清新绿
  Color(0xFF40C4FF), // 天空蓝
  Color(0xFF536DFE), // 深邃蓝
  Color(0xFFE040FB), // 神秘紫
];
