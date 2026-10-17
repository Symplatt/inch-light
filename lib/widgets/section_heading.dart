import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.count,
    this.fontSize = 16,
    this.expanded,
    this.onTap,
  });
  final String title;
  final int? count;
  final double fontSize;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
          const Spacer(),
          if (expanded != null)
            Icon(expanded! ? Icons.expand_less : Icons.expand_more, size: 22),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        key: ValueKey('section-$title'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
