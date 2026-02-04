import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/task_model.dart';
import '../constants/app_colors.dart';

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  final List<TaskItem> _timerTasks = [];
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = [];
  List<TaskCollection> _collections = [];

  Timer? _timer;
  Timer? _focusModeTrigger;
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

  // 需求7：日常打卡排序（未完成在前，已完成在后）
  List<TaskItem> get sortedDailyTasks {
    List<TaskItem> tasks = List.from(_dailyTasks);
    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return tasks;
  }

  // 获取特定状态的日常打卡（用于批量删除）
  List<TaskItem> getDailyTasks({required bool isCompleted}) {
    return _dailyTasks.where((t) => t.isCompleted == isCompleted).toList();
  }

  // 根据完成状态过滤合集中的任务
  List<TaskItem> getTasksInCollection(
    String collectionId, {
    required bool isCompleted,
  }) {
    List<TaskItem> all = _normalTasks
        .where((t) => t.collectionId == collectionId)
        .toList();
    List<TaskItem> filtered = all
        .where((t) => t.isCompleted == isCompleted)
        .toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      bool hasDeadlineA = a.deadline != null;
      bool hasDeadlineB = b.deadline != null;
      if (hasDeadlineA && !hasDeadlineB) return -1;
      if (!hasDeadlineA && hasDeadlineB) return 1;
      if (hasDeadlineA && hasDeadlineB)
        return a.deadline!.compareTo(b.deadline!);
      return a.createdAt.compareTo(b.createdAt);
    });
    return filtered;
  }

  // 根据完成状态过滤散落任务
  List<TaskItem> getLooseTasks({required bool isCompleted}) {
    List<TaskItem> tasks = _normalTasks
        .where((t) => t.collectionId == null && t.isCompleted == isCompleted)
        .toList();
    tasks.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      bool hasDeadlineA = a.deadline != null;
      bool hasDeadlineB = b.deadline != null;
      if (hasDeadlineA && !hasDeadlineB) return -1;
      if (!hasDeadlineA && hasDeadlineB) return 1;
      if (hasDeadlineA && hasDeadlineB)
        return a.deadline!.compareTo(b.deadline!);
      return a.createdAt.compareTo(b.createdAt);
    });
    return tasks;
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
          for (var item in decoded) list.add(parser(item));
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

  void setLastPageIndex(int index) {
    _lastPageIndex = index;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('last_page_index', index);
    });
  }

  String exportData() {
    final data = {
      'timer_tasks': _timerTasks.map((e) => e.toJson()).toList(),
      'daily_tasks': _dailyTasks.map((e) => e.toJson()).toList(),
      'normal_tasks': _normalTasks.map((e) => e.toJson()).toList(),
      'cycle_tasks': _cycleTasks.map((e) => e.toJson()).toList(),
      'collections': _collections.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  Future<bool> importData(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      void loadList(String key, List list, Function parser) {
        if (data[key] != null) {
          list.clear();
          for (var item in data[key]) list.add(parser(item));
        }
      }

      loadList('timer_tasks', _timerTasks, (e) => TaskItem.fromJson(e));
      loadList('daily_tasks', _dailyTasks, (e) => TaskItem.fromJson(e));
      loadList('normal_tasks', _normalTasks, (e) => TaskItem.fromJson(e));
      loadList('cycle_tasks', _cycleTasks, (e) => CycleTask.fromJson(e));
      if (data['collections'] != null) {
        _collections = (data['collections'] as List)
            .map((e) => TaskCollection.fromJson(e))
            .toList();
      }
      await _saveData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Import failed: $e");
      return false;
    }
  }

  void addCollection(String title) {
    _collections.add(TaskCollection(id: const Uuid().v4(), title: title));
    _saveData();
    notifyListeners();
  }

  void removeCollection(String collectionId) {
    for (var task in _normalTasks) {
      if (task.collectionId == collectionId) {
        task.collectionId = null;
      }
    }
    _collections.removeWhere((c) => c.id == collectionId);
    _saveData();
    notifyListeners();
  }

  // --- 批量删除功能 (需求2) ---

  // 清空日常打卡 (根据状态)
  void clearDailyTasks({required bool isCompleted}) {
    _dailyTasks.removeWhere((t) => t.isCompleted == isCompleted);
    _saveData();
    notifyListeners();
  }

  // 清空合集 (这里逻辑为：清空所有合集，内部任务释放为散落。因为合集本身不分“完成/未完成”，
  // 但为了响应前端按钮，我们简单定义为：点击清理就清理所有合集)
  void clearCollections() {
    // 释放所有合集任务
    for (var task in _normalTasks) {
      task.collectionId = null;
    }
    _collections.clear();
    _saveData();
    notifyListeners();
  }

  // 清空散落任务 (根据状态)
  void clearLooseTasks({required bool isCompleted}) {
    // 注意：只删除 loose tasks (collectionId == null)，且符合状态的
    _normalTasks.removeWhere(
      (t) => t.collectionId == null && t.isCompleted == isCompleted,
    );
    _saveData();
    notifyListeners();
  }

  // ---------------------------

  void toggleCollectionExpand(String id) {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _collections[index].isExpanded = !_collections[index].isExpanded;
      _saveData();
      notifyListeners();
    }
  }

  void addNormalTask(
    String title, {
    DateTime? deadline,
    String? collectionId,
    List<String> tags = const [],
  }) {
    _normalTasks.add(
      TaskItem(
        id: const Uuid().v4(),
        title: title,
        type: TaskType.normal,
        deadline: deadline,
        collectionId: collectionId,
        tags: tags,
      ),
    );
    _saveData();
    notifyListeners();
  }

  void addDailyTask(String title) {
    _dailyTasks.add(
      TaskItem(id: const Uuid().v4(), title: title, type: TaskType.daily),
    );
    _saveData();
    notifyListeners();
  }

  void updateTask(
    TaskItem task,
    String newTitle, {
    DateTime? newDeadline,
    List<String>? newTags,
  }) {
    task.title = newTitle;
    task.deadline = newDeadline;
    if (newTags != null) {
      task.tags = newTags;
    }
    _saveData();
    notifyListeners();
  }

  void removeTask(TaskItem task) {
    if (task.type == TaskType.timer) _timerTasks.remove(task);
    if (task.type == TaskType.daily) _dailyTasks.remove(task);
    if (task.type == TaskType.normal) _normalTasks.remove(task);
    if (task.type == TaskType.timer && _activeTimerId == task.id) stopTimer();
    _saveData();
    notifyListeners();
  }

  void addTimerTask(
    String title, {
    TimerMode mode = TimerMode.stopwatch,
    int? targetSeconds,
  }) {
    int nextColorIndex = _timerTasks.length % taskColors.length;
    _timerTasks.add(
      TaskItem(
        id: const Uuid().v4(),
        title: title,
        type: TaskType.timer,
        timerMode: mode,
        targetSeconds: targetSeconds,
        durationSeconds: mode == TimerMode.countdown ? (targetSeconds ?? 0) : 0,
        colorIndex: nextColorIndex,
      ),
    );
    _saveData();
    notifyListeners();
  }

  void deleteTimerTask(TaskItem task) => removeTask(task);
  void toggleTimer(TaskItem task) =>
      _activeTimerId == task.id ? stopTimer() : startTimer(task.id);

  void resetTimerTask(TaskItem task) {
    if (_activeTimerId == task.id) stopTimer();
    task.durationSeconds = task.timerMode == TimerMode.countdown
        ? (task.targetSeconds ?? 0)
        : 0;
    _saveData();
    notifyListeners();
  }

  void renameTimerTask(TaskItem task, String newName) {
    task.title = newName;
    _saveData();
    notifyListeners();
  }

  void startTimer(String taskId) {
    if (_activeTimerId != null && _activeTimerId != taskId) return;
    final task = _timerTasks.firstWhere((e) => e.id == taskId);
    _activeTimerId = taskId;
    WakelockPlus.enable();
    FlutterBackgroundService().invoke("setAsForeground");
    _resetFocusTrigger();
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
    _focusModeTrigger?.cancel();
    _isFocusMode = false;
    WakelockPlus.disable();
    FlutterBackgroundService().invoke("setAsBackground");
    _saveData();
    notifyListeners();
  }

  void _resetFocusTrigger() {
    _focusModeTrigger?.cancel();
    if (_activeTimerId != null) {
      _focusModeTrigger = Timer(const Duration(seconds: 20), () {
        _isFocusMode = true;
        notifyListeners();
      });
    }
  }

  void exitFocusMode() {
    if (_activeTimerId != null) {
      _isFocusMode = false;
      _resetFocusTrigger();
      notifyListeners();
    }
  }

  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.play(AssetSource('audio/alarm0.wav'));
    } catch (e) {
      debugPrint("$e");
    }
  }

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

  void removeCycleTask(CycleTask task) {
    _cycleTasks.remove(task);
    _saveData();
    notifyListeners();
  }

  DateTime _calculateNextRunTime(DateTime startTime, CycleFrequency frequency) {
    DateTime now = DateTime.now();
    DateTime next = startTime;
    if (next.isAfter(now)) return next;
    while (next.isBefore(now)) {
      switch (frequency) {
        case CycleFrequency.daily:
          next = next.add(const Duration(days: 1));
          break;
        case CycleFrequency.weekly:
          next = next.add(const Duration(days: 7));
          break;
        case CycleFrequency.monthly:
          int nextMonth = next.month + 1;
          int nextYear = next.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          int maxDays = DateTime(nextYear, nextMonth + 1, 0).day;
          int nextDay = startTime.day > maxDays ? maxDays : startTime.day;
          next = DateTime(
            nextYear,
            nextMonth,
            nextDay,
            startTime.hour,
            startTime.minute,
          );
          break;
        case CycleFrequency.yearly:
          int nextYearly = next.year + 1;
          int nextDayYearly = startTime.day;
          if (startTime.month == 2 && startTime.day == 29) {
            bool isLeap =
                (nextYearly % 4 == 0 && nextYearly % 100 != 0) ||
                (nextYearly % 400 == 0);
            if (!isLeap) nextDayYearly = 28;
          }
          next = DateTime(
            nextYearly,
            startTime.month,
            nextDayYearly,
            startTime.hour,
            startTime.minute,
          );
          break;
      }
    }
    return next;
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

  void toggleFocusMode() {
    _isFocusMode = !_isFocusMode;
    if (!_isFocusMode) _focusModeTrigger?.cancel();
    notifyListeners();
  }
}
