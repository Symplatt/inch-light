import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
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
    final color = deadlineColor(deadline, now: instant);
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w400,
          color: color,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.alarm_outlined,
                size: MediaQuery.textScalerOf(context).scale(12),
                color: color,
              ),
            ),
          ),
          TextSpan(text: DateFormat(pattern).format(deadline)),
          if (days != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Semantics(
                  label: '剩余 $days 天',
                  excludeSemantics: true,
                  child: Transform.translate(
                    offset: const Offset(0, 1),
                    child: Container(
                      key: const ValueKey('deadline-days'),
                      // No alignment/expand: an inline badge must keep its intrinsic width.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '$days',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF82988C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
