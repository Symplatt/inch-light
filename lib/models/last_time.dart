const lastTimeCategories = ['家务', '学业', '人际', '设备', '其他'];

// Count calendar days independently of daylight-saving changes and clock time.
int calendarDaysSince(DateTime date, DateTime now) {
  final local = date.toLocal();
  final today = now.toLocal();
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays
      .clamp(0, 3652059);
}

enum LastTimePeriodType { days, weekly, monthly }

class LastTimePeriod {
  const LastTimePeriod({required this.type, required this.value});
  final LastTimePeriodType type;
  final int value;

  String get label => switch (type) {
    LastTimePeriodType.days => '每 $value 天',
    LastTimePeriodType.weekly =>
      '每周${['一', '二', '三', '四', '五', '六', '日'][value - 1]}',
    LastTimePeriodType.monthly => '每月 $value 日',
  };

  DateTime nextAfter(DateTime date) {
    final local = date.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    switch (type) {
      case LastTimePeriodType.days:
        return DateTime(day.year, day.month, day.day + value);
      case LastTimePeriodType.weekly:
        final offset = (value - day.weekday + 7) % 7;
        return DateTime(
          day.year,
          day.month,
          day.day + (offset == 0 ? 7 : offset),
        );
      case LastTimePeriodType.monthly:
        // A short month uses its final day, and the next month keeps the chosen day.
        DateTime inMonth(int year, int month) => DateTime(
          year,
          month,
          value.clamp(1, DateTime(year, month + 1, 0).day),
        );
        final candidate = inMonth(day.year, day.month);
        return candidate.isAfter(day)
            ? candidate
            : inMonth(day.year, day.month + 1);
    }
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'value': value};

  factory LastTimePeriod.fromJson(Map<String, dynamic> json) {
    final type = LastTimePeriodType.values.byName(json['type'] as String);
    final value = json['value'] as int;
    final maximum = switch (type) {
      LastTimePeriodType.days => 3652059,
      LastTimePeriodType.weekly => 7,
      LastTimePeriodType.monthly => 31,
    };
    if (value < 1 || value > maximum) {
      throw const FormatException('Invalid last-time period');
    }
    return LastTimePeriod(type: type, value: value);
  }
}

class LastTimeItem {
  const LastTimeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.lastDate,
    this.startDate,
    this.period,
  });
  final String id;
  final String name;
  final String category;
  final DateTime lastDate;
  final DateTime? startDate;
  final LastTimePeriod? period;

  int overdueDays(DateTime now) =>
      period == null ? 0 : calendarDaysSince(period!.nextAfter(lastDate), now);

  int remainingDays(DateTime now) =>
      period == null ? 0 : calendarDaysSince(now, period!.nextAfter(lastDate));

  int elapsedDays(DateTime now) => calendarDaysSince(lastDate, now);

  LastTimeItem doneOn(DateTime date) => LastTimeItem(
    id: id,
    name: name,
    category: category,
    lastDate: date,
    period: period,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'lastDate': lastDate.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'period': period?.toJson(),
  };

  factory LastTimeItem.fromJson(Map<String, dynamic> json) {
    // Removed categories remain readable in existing data and older backups.
    final category = switch (json['category'] as String) {
      '健康' || '宠物' => '其他',
      final category => category,
    };
    final item = LastTimeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: category,
      lastDate: DateTime.parse(json['lastDate'] as String),
      period: json['period'] == null
          ? null
          : LastTimePeriod.fromJson(
              Map<String, dynamic>.from(json['period'] as Map),
            ),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
    );
    if ((item.startDate != null && item.startDate!.isAfter(item.lastDate)) ||
        item.id.isEmpty ||
        item.name.trim().isEmpty ||
        !lastTimeCategories.contains(item.category)) {
      throw const FormatException('Invalid last-time item');
    }
    return item;
  }
}

class LastTimeData {
  LastTimeData({List<LastTimeItem> items = const []})
    : items = List.unmodifiable(items);
  final List<LastTimeItem> items;

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory LastTimeData.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List)
        .map((i) => LastTimeItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();
    if (items.map((i) => i.id).toSet().length != items.length) {
      throw const FormatException('Duplicate last-time item');
    }
    return LastTimeData(items: items);
  }
}
