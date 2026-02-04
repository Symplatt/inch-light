enum TaskType { timer, daily, normal }

enum TimerMode { stopwatch, countdown }

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

  // 计时专用属性
  int colorIndex;
  TimerMode timerMode;
  int durationSeconds;
  int? targetSeconds;

  // 任务专用属性
  bool isCompleted;
  DateTime? deadline;
  List<String> tags;
  DateTime? finishedAt;
  bool isPinned;
  DateTime createdAt;
  String? collectionId;

  TaskItem({
    required this.id,
    required this.title,
    required this.type,
    this.colorIndex = 0,
    this.timerMode = TimerMode.stopwatch,
    this.durationSeconds = 0,
    this.targetSeconds,
    this.isCompleted = false,
    this.deadline,
    this.tags = const [],
    this.finishedAt,
    this.isPinned = false,
    DateTime? createdAt,
    this.collectionId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.index,
    'colorIndex': colorIndex,
    'timerMode': timerMode.index,
    'durationSeconds': durationSeconds,
    'targetSeconds': targetSeconds,
    'isCompleted': isCompleted,
    'deadline': deadline?.toIso8601String(),
    'tags': tags,
    'finishedAt': finishedAt?.toIso8601String(),
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'collectionId': collectionId,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'],
      title: json['title'],
      type: TaskType.values[json['type']],
      colorIndex: json['colorIndex'] ?? 0,
      timerMode: TimerMode.values[json['timerMode'] ?? 0],
      durationSeconds: json['durationSeconds'] ?? 0,
      targetSeconds: json['targetSeconds'],
      isCompleted: json['isCompleted'] ?? false,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'])
          : null,
      isPinned: json['isPinned'] ?? false,
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

  CycleTask({
    required this.id,
    required this.title,
    required this.frequency,
    required this.time,
    this.specificValue,
    required this.nextRunTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'frequency': frequency.index,
    'time': time.toIso8601String(),
    'specificValue': specificValue,
    'nextRunTime': nextRunTime.toIso8601String(),
  };

  factory CycleTask.fromJson(Map<String, dynamic> json) {
    return CycleTask(
      id: json['id'],
      title: json['title'],
      frequency: CycleFrequency.values[json['frequency']],
      time: DateTime.parse(json['time']),
      specificValue: json['specificValue'],
      nextRunTime: DateTime.parse(json['nextRunTime']),
    );
  }
}
