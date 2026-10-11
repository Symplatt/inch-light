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
            TextSpan(
              text: '（剩余 $days 天）',
              style: const TextStyle(
                color: Color(0xFF8D9198),
                fontWeight: FontWeight.w300,
              ),
            ),
        ],
      ),
    );
  }
}
