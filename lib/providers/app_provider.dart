import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/task_model.dart';

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  final List<TaskItem> _timerTasks = [];
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = [];
  List<TaskCollection> _collections = [];

  Timer? _timer;
  Timer? _focusModeTrigger; // 如果后续做专注模式触发器会用到，暂保留
  String? _activeTimerId;

  bool _isFocusMode = false;
  int _lastPageIndex = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Getters
  List<TaskItem> get timerTasks => _timerTasks;
  List<TaskItem> get dailyTasks => _dailyTasks;
  List<TaskItem> get normalTasks => _normalTasks;
  List<CycleTask> get cycleTasks => _cycleTasks;
  List<TaskCollection> get collections => _collections;
  String? get activeTimerId => _activeTimerId;
  bool get isFocusMode => _isFocusMode;
  int get lastPageIndex => _lastPageIndex;

  // 排序后的普通任务
  List<TaskItem> get sortedNormalTasks {
    List<TaskItem> tasks = List.from(_normalTasks);
    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      bool hasDeadlineA = a.deadline != null;
      bool hasDeadlineB = b.deadline != null;
      if (hasDeadlineA && !hasDeadlineB) return -1;
      if (!hasDeadlineA && hasDeadlineB) return 1;
      if (hasDeadlineA && hasDeadlineB) {
        return a.deadline!.compareTo(b.deadline!);
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    });
    return tasks;
  }

  List<TaskItem> getTasksInCollection(String collectionId) {
    return sortedNormalTasks
        .where((t) => t.collectionId == collectionId)
        .toList();
  }

  List<TaskItem> get looseTasks {
    return sortedNormalTasks.where((t) => t.collectionId == null).toList();
  }

  AppProvider() {
    _initData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _focusModeTrigger?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndResetDailyTasks();
    }
  }

  // ================= 数据初始化 =================

  Future<void> _initData() async {
    await _loadData();
    notifyListeners();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    void safeLoad(
      String key,
      List<dynamic> list,
      Function(Map<String, dynamic>) parser,
    ) {
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        try {
          final List<dynamic> decoded = json.decode(jsonString);
          list.clear();
          for (var item in decoded) {
            list.add(parser(item));
          }
        } catch (e) {
          debugPrint("Error parsing $key: $e");
        }
      }
    }

    safeLoad('timer_tasks', _timerTasks, (json) => TaskItem.fromJson(json));
    safeLoad('daily_tasks', _dailyTasks, (json) => TaskItem.fromJson(json));
    safeLoad('normal_tasks', _normalTasks, (json) => TaskItem.fromJson(json));
    safeLoad('cycle_tasks', _cycleTasks, (json) => CycleTask.fromJson(json));

    final collectionsJson = prefs.getString('collections_data');
    if (collectionsJson != null) {
      try {
        final List<dynamic> list = json.decode(collectionsJson);
        _collections = list.map((e) => TaskCollection.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Error parsing collections: $e");
      }
    }

    _lastPageIndex = prefs.getInt('last_page_index') ?? 0;
    await _checkAndResetDailyTasks();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String encode(List<dynamic> list) =>
        json.encode(list.map((e) => e.toJson()).toList());

    await prefs.setString('timer_tasks', encode(_timerTasks));
    await prefs.setString('daily_tasks', encode(_dailyTasks));
    await prefs.setString('normal_tasks', encode(_normalTasks));
    await prefs.setString('cycle_tasks', encode(_cycleTasks));
    await prefs.setString('collections_data', encode(_collections));
  }

  Future<void> _checkAndResetDailyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String lastResetDateStr =
        prefs.getString('last_daily_reset_date') ?? '';
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];

    if (lastResetDateStr != todayStr) {
      bool hasChanges = false;
      for (var task in _dailyTasks) {
        if (task.isCompleted) {
          task.isCompleted = false;
          task.finishedAt = null;
          hasChanges = true;
        }
      }
      await prefs.setString('last_daily_reset_date', todayStr);
      if (hasChanges) {
        notifyListeners();
        _saveData();
      }
    }
  }

  // ================= 页面记忆 =================

  void setLastPageIndex(int index) {
    _lastPageIndex = index;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('last_page_index', index);
    });
  }

  // ================= 任务操作方法 =================

  // --- 合集 ---
  void addCollection(String title) {
    _collections.add(TaskCollection(id: const Uuid().v4(), title: title));
    _saveData();
    notifyListeners();
  }

  void toggleCollectionExpand(String id) {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _collections[index].isExpanded = !_collections[index].isExpanded;
      _saveData();
      notifyListeners();
    }
  }

  // --- 通用任务操作 ---
  void addTaskToCollection(TaskItem task, String? collectionId) {
    task.collectionId = collectionId;
    _normalTasks.add(task);
    _saveData();
    notifyListeners();
  }

  void removeTask(TaskItem task) {
    if (task.type == TaskType.timer) _timerTasks.remove(task);
    if (task.type == TaskType.daily) _dailyTasks.remove(task);
    if (task.type == TaskType.normal) _normalTasks.remove(task);

    if (task.type == TaskType.timer && _activeTimerId == task.id) {
      stopTimer();
    }

    _saveData();
    notifyListeners();
  }

  // 包装方法：接收 TaskItem 以匹配 TimerPage 逻辑
  void deleteTimerTask(TaskItem task) {
    removeTask(task);
  }

  void removeCycleTask(CycleTask task) {
    _cycleTasks.remove(task);
    _saveData();
    notifyListeners();
  }

  void toggleTaskCompletion(TaskItem task) {
    task.isCompleted = !task.isCompleted;
    task.finishedAt = task.isCompleted ? DateTime.now() : null;
    _saveData();
    notifyListeners();
  }

  void toggleTaskPin(TaskItem task) {
    task.isPinned = !task.isPinned;
    _saveData();
    notifyListeners();
  }

  void renameTimerTask(TaskItem task, String newName) {
    task.title = newName;
    _saveData();
    notifyListeners();
  }

  void updateTaskColor(TaskItem task, int colorIndex) {
    task.colorIndex = colorIndex;
    _saveData();
    notifyListeners();
  }

  // --- 计时器逻辑 ---

  // 修复：支持传入模式和目标时间
  void addTimerTask(
    String title, {
    TimerMode mode = TimerMode.stopwatch,
    int? targetSeconds,
  }) {
    _timerTasks.add(
      TaskItem(
        id: const Uuid().v4(),
        title: title,
        type: TaskType.timer,
        timerMode: mode,
        targetSeconds: targetSeconds,
        durationSeconds: mode == TimerMode.countdown ? (targetSeconds ?? 0) : 0,
      ),
    );
    _saveData();
    notifyListeners();
  }

  void startTimer(String taskId) {
    if (_activeTimerId != null && _activeTimerId != taskId) return;

    final task = _timerTasks.firstWhere((e) => e.id == taskId);
    _activeTimerId = taskId;

    WakelockPlus.enable();
    FlutterBackgroundService().invoke("setAsForeground");

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (task.timerMode == TimerMode.stopwatch) {
        task.durationSeconds++;
      } else {
        if (task.durationSeconds > 0) {
          task.durationSeconds--;
        } else {
          stopTimer();
          _playAlarm();
        }
      }
      _saveData();
      notifyListeners();
    });
    notifyListeners();
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _activeTimerId = null;
    WakelockPlus.disable();
    FlutterBackgroundService().invoke("setAsBackground");
    _saveData();
    notifyListeners();
  }

  void toggleTimer(TaskItem task) {
    if (_activeTimerId == task.id) {
      stopTimer();
    } else {
      startTimer(task.id);
    }
  }

  void resetTimerTask(TaskItem task) {
    if (_activeTimerId == task.id) {
      stopTimer();
    }
    if (task.timerMode == TimerMode.countdown) {
      task.durationSeconds = task.targetSeconds ?? 0;
    } else {
      task.durationSeconds = 0;
    }
    _saveData();
    notifyListeners();
  }

  void toggleTimerMode(TaskItem task) {
    if (_activeTimerId == task.id) return;
    task.timerMode = task.timerMode == TimerMode.stopwatch
        ? TimerMode.countdown
        : TimerMode.stopwatch;
    _saveData();
    notifyListeners();
  }

  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.play(AssetSource('audio/alarm0.wav'));
    } catch (e) {
      debugPrint("Play alarm failed: $e");
    }
  }

  void toggleFocusMode() {
    _isFocusMode = !_isFocusMode;
    if (!_isFocusMode) {
      _focusModeTrigger?.cancel();
    }
    notifyListeners();
  }

  // --- 周期任务 ---
  void addCycleTask(String title, CycleFrequency frequency, DateTime time) {
    _cycleTasks.add(
      CycleTask(
        id: const Uuid().v4(),
        title: title,
        frequency: frequency,
        time: time,
        nextRunTime: _calculateNextRunTime(time, frequency),
      ),
    );
    _saveData();
    notifyListeners();
  }

  DateTime _calculateNextRunTime(DateTime startTime, CycleFrequency frequency) {
    DateTime now = DateTime.now();
    DateTime next = startTime;
    while (next.isBefore(now)) {
      switch (frequency) {
        case CycleFrequency.daily:
          next = next.add(const Duration(days: 1));
          break;
        case CycleFrequency.weekly:
          next = next.add(const Duration(days: 7));
          break;
        case CycleFrequency.monthly:
          next = DateTime(
            next.year,
            next.month + 1,
            next.day,
            next.hour,
            next.minute,
          );
          break;
        case CycleFrequency.yearly:
          next = DateTime(
            next.year + 1,
            next.month,
            next.day,
            next.hour,
            next.minute,
          );
          break;
      }
    }
    return next;
  }
}
