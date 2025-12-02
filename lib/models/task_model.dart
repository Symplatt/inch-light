// 任务类型枚举
enum TaskType { timer, daily, normal }

// 计时模式枚举
enum TimerMode { stopwatch, countdown }

// 周期频率枚举
enum CycleFrequency { daily, weekly, monthly, yearly }

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

// 周期任务模型
class CycleTask {
  String id;
  String title;
  CycleFrequency frequency;
  DateTime time; // 设定的具体时间（只取时分，或日期）
  int? specificValue; // 周几(1-7) 或 月几(1-31)
  DateTime nextRunTime; // 下一次提醒时间（用于排序）

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
