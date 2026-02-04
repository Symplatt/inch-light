import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/task_model.dart';
import '../constants/app_colors.dart'; // 需要读取 taskColors 长度

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  final List<TaskItem> _timerTasks = [];
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = [];
  List<TaskCollection> _collections = [];

  Timer? _timer;
  Timer? _focusModeTrigger; // 20秒自动进入沉浸模式的触发器
  String? _activeTimerId;
  bool _isFocusMode = false; // 是否处于沉浸黑屏模式
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

  // 排序保持不变
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

  // ... (InitData, LoadData, SaveData, CheckReset, SetLastPage, Export/Import 逻辑保持不变)
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

  void removeTask(TaskItem task) {
    if (task.type == TaskType.timer) _timerTasks.remove(task);
    if (task.type == TaskType.daily) _dailyTasks.remove(task);
    if (task.type == TaskType.normal) _normalTasks.remove(task);
    if (task.type == TaskType.timer && _activeTimerId == task.id) stopTimer();
    _saveData();
    notifyListeners();
  }

  // --- 专注逻辑升级 ---

  // 需求4：每个新建任务颜色轮流 (index % 7)
  void addTimerTask(
    String title, {
    TimerMode mode = TimerMode.stopwatch,
    int? targetSeconds,
  }) {
    int nextColorIndex = _timerTasks.length % taskColors.length; // 自动分配颜色
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

    // 需求5：开启20秒自动进入专注增强模式
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
    _focusModeTrigger?.cancel(); // 停止计时则取消黑屏触发
    _isFocusMode = false; // 退出黑屏
    WakelockPlus.disable();
    FlutterBackgroundService().invoke("setAsBackground");
    _saveData();
    notifyListeners();
  }

  // 触发 20秒 倒计时
  void _resetFocusTrigger() {
    _focusModeTrigger?.cancel();
    if (_activeTimerId != null) {
      _focusModeTrigger = Timer(const Duration(seconds: 20), () {
        _isFocusMode = true;
        notifyListeners();
      });
    }
  }

  // 用户点击屏幕唤醒时调用
  void exitFocusMode() {
    if (_activeTimerId != null) {
      _isFocusMode = false;
      _resetFocusTrigger(); // 重置20秒
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

  // 周期逻辑
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
