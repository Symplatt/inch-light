const lastTimeCategories = ['家务', '健康', '人际', '宠物', '设备', '其他'];

// Count calendar days independently of daylight-saving changes and clock time.
int calendarDaysSince(DateTime date, DateTime now) {
  final local = date.toLocal();
  final today = now.toLocal();
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays
      .clamp(0, 3652059);
}

class LastTimeItem {
  const LastTimeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.lastDate,
    this.startDate,
  });
  final String id;
  final String name;
  final String category;
  final DateTime lastDate;
  final DateTime? startDate;

  int elapsedDays(DateTime now) => calendarDaysSince(lastDate, now);

  LastTimeItem doneOn(DateTime date) =>
      LastTimeItem(id: id, name: name, category: category, lastDate: date);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'lastDate': lastDate.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
  };

  factory LastTimeItem.fromJson(Map<String, dynamic> json) {
    final item = LastTimeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      lastDate: DateTime.parse(json['lastDate'] as String),
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
