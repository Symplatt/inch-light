import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/deadline.dart';

class DeadlineLabel extends StatelessWidget {
  const DeadlineLabel({
    super.key,
    required this.deadline,
    this.pattern = 'MM-dd HH:mm',
    this.now,
  });
  final DateTime deadline;
  final String pattern;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final instant = now ?? DateTime.now();
    final days = greenDeadlineDays(deadline, now: instant);
    return Text.rich(
      TextSpan(
        text: DateFormat(pattern).format(deadline),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: deadlineColor(deadline, now: instant),
        ),
        children: [
          if (days != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Semantics(
                  label: '剩余 $days 天',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        size: 13,
                        color: Color(0xFF8D9198),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$days',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8D9198),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
