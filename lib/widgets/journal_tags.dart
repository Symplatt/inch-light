import 'package:flutter/material.dart';

class JournalTags extends StatelessWidget {
  const JournalTags({super.key, required this.tags, this.compact = false});
  final List<String> tags;
  final bool compact;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: compact ? 4 : 8,
    runSpacing: compact ? 4 : 8,
    children: tags
        .map(
          (tag) => Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 10,
              vertical: compact ? 2 : 5,
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
