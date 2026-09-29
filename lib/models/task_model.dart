enum TaskType { daily, normal }

enum CycleFrequency { daily, weekly, monthly, yearly }

class TaskCollection {
  String id;
  String title;
  bool isExpanded;

  TaskCollection({
    required this.id,
    required this.title,
    this.isExpanded = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isExpanded': isExpanded,
  };

  factory TaskCollection.fromJson(Map<String, dynamic> json) {
    return TaskCollection(
      id: json['id'],
      title: json['title'],
      isExpanded: json['isExpanded'] ?? true,
    );
  }
}

class TaskItem {
  String id;
  String title;
  TaskType type;

  // 任务专用属性
  bool isCompleted;
  DateTime? deadline;
  List<String> tags;
  DateTime? finishedAt;
  bool isPinned;
  bool isBottom;
  DateTime createdAt;
  String? collectionId;

  TaskItem({
    required this.id,
    required this.title,
    required this.type,
    this.isCompleted = false,
    this.deadline,
    this.tags = const [],
    this.finishedAt,
    this.isPinned = false,
    this.isBottom = false,
    DateTime? createdAt,
    this.collectionId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type == TaskType.daily ? 1 : 2, // 保持已有数据的类型编号
    'isCompleted': isCompleted,
    'deadline': deadline?.toIso8601String(),
    'tags': tags,
    'finishedAt': finishedAt?.toIso8601String(),
    'isPinned': isPinned,
    'isBottom': isBottom,
    'createdAt': createdAt.toIso8601String(),
    'collectionId': collectionId,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'],
      title: json['title'],
      type: json['type'] == 1 ? TaskType.daily : TaskType.normal,
      isCompleted: json['isCompleted'] ?? false,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'])
          : null,
      isPinned: json['isPinned'] ?? false,
      isBottom: json['isBottom'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      collectionId: json['collectionId'],
    );
  }
}

class CycleTask {
  String id;
  String title;
  CycleFrequency frequency;
  DateTime time;
  int? specificValue;
  DateTime nextRunTime;
  bool allDay;

  CycleTask({
    required this.id,
    required this.title,
    required this.frequency,
    required this.time,
    this.specificValue,
    required this.nextRunTime,
    this.allDay = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'frequency': frequency.index,
    'time': time.toIso8601String(),
    'specificValue': specificValue,
    'nextRunTime': nextRunTime.toIso8601String(),
    'allDay': allDay,
  };

  factory CycleTask.fromJson(Map<String, dynamic> json) {
    return CycleTask(
      id: json['id'],
      title: json['title'],
      frequency: CycleFrequency.values[json['frequency']],
      time: DateTime.parse(json['time']),
      specificValue: json['specificValue'],
      nextRunTime: DateTime.parse(json['nextRunTime']),
      allDay: json['allDay'] ?? false,
    );
  }
}

class JournalEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class CalendarCountdown {
  final String id;
  final String title;
  final DateTime deadline;
  CalendarCountdown({
    required this.id,
    required this.title,
    required this.deadline,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'deadline': deadline.toIso8601String(),
  };
  factory CalendarCountdown.fromJson(Map<String, dynamic> json) =>
      CalendarCountdown(
        id: json['id'],
        title: json['title'],
        deadline: DateTime.parse(json['deadline']),
      );
}
