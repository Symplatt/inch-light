import '../models/task_model.dart';

/// Preserves the original day across short months and leap years.
DateTime nextOccurrence(
  DateTime anchor,
  CycleFrequency frequency,
  DateTime after,
) {
  if (anchor.isAfter(after)) return anchor;
  DateTime at(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      anchor.day.clamp(1, lastDay),
      anchor.hour,
      anchor.minute,
    );
  }

  switch (frequency) {
    case CycleFrequency.daily:
    case CycleFrequency.weekly:
      final step = frequency == CycleFrequency.daily ? 1 : 7;
      final days = DateTime(
        after.year,
        after.month,
        after.day,
      ).difference(DateTime(anchor.year, anchor.month, anchor.day)).inDays;
      var n = (days ~/ step).clamp(0, 100000000);
      var candidate = DateTime(
        anchor.year,
        anchor.month,
        anchor.day + n * step,
        anchor.hour,
        anchor.minute,
      );
      while (!candidate.isAfter(after)) {
        n++;
        candidate = DateTime(
          anchor.year,
          anchor.month,
          anchor.day + n * step,
          anchor.hour,
          anchor.minute,
        );
      }
      return candidate;
    case CycleFrequency.monthly:
      var candidate = at(after.year, after.month);
      if (!candidate.isAfter(after)) {
        candidate = at(after.year, after.month + 1);
      }
      return candidate;
    case CycleFrequency.yearly:
      var candidate = at(after.year, anchor.month);
      if (!candidate.isAfter(after)) {
        candidate = at(after.year + 1, anchor.month);
      }
      return candidate;
  }
}
