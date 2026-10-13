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
    final color = deadlineColor(deadline, now: instant);
    final style = TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: color,
    );
    final height = MediaQuery.textScalerOf(context).scale(12) * 1.2;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Semantics(
                label: days != null
                    ? '剩余 $days 天'
                    : deadline.isBefore(instant)
                    ? '已过期'
                    : '即将到期',
                excludeSemantics: true,
                child: days != null
                    ? Container(
                        key: const ValueKey('deadline-days'),
                        constraints: BoxConstraints(minWidth: height),
                        height: height,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$days',
                          style: style.copyWith(fontSize: 10, height: 1),
                        ),
                      )
                    : deadline.isBefore(instant)
                    ? Icon(Icons.error_rounded, size: height, color: color)
                    : SizedBox.square(
                        dimension: height,
                        child: CustomPaint(painter: _AlarmPainter(color)),
                      ),
              ),
            ),
          ),
          TextSpan(text: DateFormat(pattern).format(deadline)),
        ],
      ),
    );
  }
}

class _AlarmPainter extends CustomPainter {
  const _AlarmPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    final fill = Paint()..color = color;
    canvas.drawCircle(const Offset(8, 8.5), 5.8, fill);
    canvas.drawOval(const Rect.fromLTWH(.4, .5, 5.5, 3.4), fill);
    canvas.drawOval(const Rect.fromLTWH(10.1, .5, 5.5, 3.4), fill);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4.5, 13), const Offset(3.5, 15), stroke);
    canvas.drawLine(const Offset(11.5, 13), const Offset(12.5, 15), stroke);
    stroke.color = Colors.white;
    canvas.drawLine(const Offset(8, 5), const Offset(8, 8.5), stroke);
    canvas.drawLine(const Offset(8, 8.5), const Offset(10.5, 10), stroke);
  }

  @override
  bool shouldRepaint(_AlarmPainter old) => old.color != color;
}
