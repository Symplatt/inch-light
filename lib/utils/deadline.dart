import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

Color deadlineColor(DateTime? deadline, {DateTime? now}) {
  if (deadline == null) return AppColors.textGrey;
  final remaining = deadline.difference(now ?? DateTime.now());
  if (remaining.isNegative) return AppColors.danger;
  return remaining <= const Duration(hours: 24)
      ? const Color(0xFFC9A000)
      : AppColors.success;
}
