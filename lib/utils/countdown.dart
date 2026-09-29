/// Calendar years/months are measured from now, clamping month-end dates.
/// Values show complete units; under 24 hours uses the actual duration.
List<({int value, String unit})> countdownParts(
  DateTime deadline,
  DateTime now,
) {
  final remaining = deadline.difference(now);
  if (remaining <= Duration.zero) return [];
  if (remaining < const Duration(days: 1)) {
    return [
      (value: remaining.inHours, unit: '时'),
      (value: remaining.inMinutes % 60, unit: '分'),
      (value: remaining.inSeconds % 60, unit: '秒'),
    ];
  }
  DateTime atMonth(int months) {
    final first = DateTime(now.year, now.month + months);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(
      first.year,
      first.month,
      now.day.clamp(1, lastDay),
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  var months = (deadline.year - now.year) * 12 + deadline.month - now.month;
  if (atMonth(months).isAfter(deadline)) months--;
  final anchor = atMonth(months);
  // UTC date components count calendar days without daylight-saving drift.
  var days = DateTime.utc(
    deadline.year,
    deadline.month,
    deadline.day,
  ).difference(DateTime.utc(anchor.year, anchor.month, anchor.day)).inDays;
  final candidate = DateTime(
    anchor.year,
    anchor.month,
    anchor.day + days,
    anchor.hour,
    anchor.minute,
    anchor.second,
    anchor.millisecond,
    anchor.microsecond,
  );
  if (candidate.isAfter(deadline)) days--;
  return [
    (value: months ~/ 12, unit: '年'),
    (value: months % 12, unit: '月'),
    (value: days, unit: '日'),
  ];
}
