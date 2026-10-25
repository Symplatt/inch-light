import 'package:flutter/material.dart';

class JournalTags extends StatelessWidget {
  const JournalTags({super.key, required this.tags, this.compact = false});
  final List<String> tags;
  final bool compact;
  static double compactHeight(BuildContext context) {
    // Match the metadata's nominal glyph height, without its line leading.
    return MediaQuery.textScalerOf(context).scale(12);
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
                fontSize: compact ? 9 : 13,
                height: compact ? 1 : null,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        )
        .toList(),
  );
}
