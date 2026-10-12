import 'package:flutter/material.dart';

class JournalTags extends StatelessWidget {
  const JournalTags({super.key, required this.tags, this.compact = false});
  final List<String> tags;
  final bool compact;
  static double compactHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: '日期 00字',
        style: DefaultTextStyle.of(
          context,
        ).style.merge(const TextStyle(fontSize: 12)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: compact ? 4 : 8,
    runSpacing: compact ? 4 : 8,
    children: tags
        .map(
          (tag) => Container(
            height: compact ? compactHeight(context) : null,
            alignment: compact ? Alignment.center : null,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 10,
              vertical: compact ? 0 : 5,
            ),
            decoration: BoxDecoration(
              color: Color(compact ? 0xFFF5F5F5 : 0xFFF0F0F0),
              borderRadius: BorderRadius.circular(compact ? 4 : 8),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: Color(compact ? 0xFF767676 : 0xFF252525),
                fontSize: compact ? 10 : 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        )
        .toList(),
  );
}
