/// Log dates follow local calendar days, with the boundary at 04:00.
DateTime workLogDay(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.hour < 4 ? 1 : 0));

String workLogDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class WorkLogColumn {
  const WorkLogColumn({required this.id, required this.name});
  final String id;
  final String name;

  bool get isFixed =>
      const {'study', 'work', 'other'}.contains(id) ||
      const {'学习', '工作', '其他'}.contains(name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory WorkLogColumn.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (id.isEmpty || name.trim().isEmpty) {
      throw const FormatException('Invalid work log column');
    }
    return WorkLogColumn(id: id, name: name);
  }
}

class WorkLogItem {
  const WorkLogItem({
    required this.id,
    required this.columnId,
    required this.text,
  });
  final String id;
  final String columnId;
  final String text;

  Map<String, dynamic> toJson() => {
    'id': id,
    'columnId': columnId,
    'text': text,
  };

  factory WorkLogItem.fromJson(Map<String, dynamic> json) {
    final item = WorkLogItem(
      id: json['id'] as String,
      columnId: json['columnId'] as String,
      text: json['text'] as String,
    );
    if (item.id.isEmpty || item.text.trim().isEmpty) {
      throw const FormatException('Invalid work log item');
    }
    return item;
  }
}

class WorkLogData {
  static const defaultColumns = [
    WorkLogColumn(id: 'study', name: '学习'),
    WorkLogColumn(id: 'work', name: '工作'),
    WorkLogColumn(id: 'other', name: '其他'),
  ];

  factory WorkLogData({
    required List<WorkLogColumn> columns,
    required Map<String, List<WorkLogItem>> days,
  }) {
    // Normalize old data and imported backups through the same migration.
    final skillIds = columns
        .where((c) => c.id == 'skill')
        .map((c) => c.id)
        .toSet();
    final normalized = columns.where((c) => !skillIds.contains(c.id)).toList();
    for (final column in defaultColumns) {
      if (!normalized.any((c) => c.id == column.id || c.name == column.name)) {
        normalized.add(column);
      }
    }
    final study = normalized.firstWhere(
      (c) => c.id == 'study' || c.name == '学习',
    );
    return WorkLogData._(
      columns: normalized,
      days: {
        for (final day in days.entries)
          day.key: [
            for (final item in day.value)
              skillIds.contains(item.columnId)
                  ? WorkLogItem(
                      id: item.id,
                      columnId: study.id,
                      text: item.text,
                    )
                  : item,
          ],
      },
    );
  }

  WorkLogData._({
    required List<WorkLogColumn> columns,
    required Map<String, List<WorkLogItem>> days,
  }) : columns = List.unmodifiable(columns),
       days = Map.unmodifiable({
         for (final day in days.entries)
           day.key: List<WorkLogItem>.unmodifiable(day.value),
       });

  factory WorkLogData.empty() =>
      WorkLogData(columns: defaultColumns, days: const {});

  final List<WorkLogColumn> columns;
  // Empty dates are derived by the UI, so daily cards also appear after offline use.
  final Map<String, List<WorkLogItem>> days;

  WorkLogData addColumn(WorkLogColumn column) {
    if (columns.any(
      (c) => c.name.trim().toLowerCase() == column.name.trim().toLowerCase(),
    )) {
      throw StateError('栏目名称已存在');
    }
    final next = [...columns];
    // Keep Other last by default while respecting an explicitly reordered list.
    final otherIsLast =
        next.isNotEmpty && (next.last.id == 'other' || next.last.name == '其他');
    next.insert(otherIsLast ? next.length - 1 : next.length, column);
    return WorkLogData(columns: next, days: days);
  }

  WorkLogData renameColumn(String id, String name) {
    final column = columns.firstWhere((c) => c.id == id);
    if (column.isFixed) throw StateError('基础栏目不可改名');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('请输入栏目名称');
    if (columns.any(
      (c) => c.id != id && c.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw StateError('栏目名称已存在');
    }
    return WorkLogData(
      columns: columns
          .map((c) => c.id == id ? WorkLogColumn(id: id, name: trimmed) : c)
          .toList(),
      days: days,
    );
  }

  WorkLogData removeColumn(String id) {
    final column = columns.firstWhere((c) => c.id == id);
    if (column.isFixed) throw StateError('固定栏目不可删除');
    final other = columns.firstWhere((c) => c.id == 'other' || c.name == '其他');
    return WorkLogData(
      columns: columns.where((c) => c.id != id).toList(),
      days: {
        for (final day in days.entries)
          day.key: [
            for (final item in day.value)
              item.columnId == id
                  ? WorkLogItem(
                      id: item.id,
                      columnId: other.id,
                      text: item.text,
                    )
                  : item,
          ],
      },
    );
  }

  WorkLogData moveColumn(String id, String? beforeId) {
    final next = [...columns];
    final index = next.indexWhere((c) => c.id == id);
    if (index < 0) return this;
    final moving = next.removeAt(index);
    final target = next.indexWhere((c) => c.id == beforeId);
    next.insert(target < 0 ? next.length : target, moving);
    return WorkLogData(columns: next, days: days);
  }

  WorkLogData saveItem(String day, WorkLogItem item) {
    if (!columns.any((c) => c.id == item.columnId)) throw StateError('栏目不存在');
    final items = [...?days[day]];
    final index = items.indexWhere((e) => e.id == item.id);
    if (index < 0) {
      items.add(item);
    } else {
      items[index] = item;
    }
    return WorkLogData(columns: columns, days: {...days, day: items});
  }

  WorkLogData removeItem(String day, String id) {
    final next = {...days};
    final items = [...?days[day]]..removeWhere((e) => e.id == id);
    if (items.isEmpty) {
      next.remove(day);
    } else {
      next[day] = items;
    }
    return WorkLogData(columns: columns, days: next);
  }

  Map<String, dynamic> toJson() => {
    'columns': columns.map((c) => c.toJson()).toList(),
    'days': {
      for (final day in days.entries)
        day.key: day.value.map((e) => e.toJson()).toList(),
    },
  };

  factory WorkLogData.fromJson(Map<String, dynamic> json) {
    final columns = (json['columns'] as List)
        .map((e) => WorkLogColumn.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final columnIds = columns.map((c) => c.id).toSet();
    if (columns.isEmpty ||
        columnIds.length != columns.length ||
        columns.map((c) => c.name.trim().toLowerCase()).toSet().length !=
            columns.length) {
      throw const FormatException('Invalid work log columns');
    }
    final ids = <String>{};
    final days = <String, List<WorkLogItem>>{};
    for (final day in (json['days'] as Map).entries) {
      final key = day.key as String;
      if (workLogDateKey(DateTime.parse(key)) != key) {
        throw const FormatException('Invalid work log date');
      }
      days[key] = (day.value as List).map((raw) {
        final item = WorkLogItem.fromJson(Map<String, dynamic>.from(raw));
        if (!columnIds.contains(item.columnId) || !ids.add(item.id)) {
          throw const FormatException('Invalid work log item reference');
        }
        return item;
      }).toList();
    }
    return WorkLogData(columns: columns, days: days);
  }
}
