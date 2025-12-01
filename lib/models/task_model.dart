enum TaskType { timer, daily, normal }

enum TimerMode { stopwatch, countdown }

class TaskItem {
  String id;
  String title;
  TaskType type;

  // 计时专用
  int colorIndex;
  TimerMode timerMode;
  int durationSeconds;
  int? targetSeconds;

  // 记事专用
  bool isCompleted;
  DateTime? deadline;
  List<String> tags;
  DateTime? finishedAt;

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
  });

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
    );
  }
}
