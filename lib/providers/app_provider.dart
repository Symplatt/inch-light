import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';

class AppProvider with ChangeNotifier {
  // 四种任务列表
  final List<TaskItem> _timerTasks = [];
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = []; // 新增：周期任务

  Timer? _timer;
  String? _activeTimerId;

  // Getters
  List<TaskItem> get timerTasks => _timerTasks;
  List<TaskItem> get dailyTasks => _dailyTasks;
  List<TaskItem> get normalTasks => _normalTasks;
  List<CycleTask> get cycleTasks => _cycleTasks;
  String? get activeTimerId => _activeTimerId;

  AppProvider() {
    _loadData();
  }

  // ==================== 数据持久化 ====================

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastOpenDate = prefs.getString('lastOpenDate');
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 通用加载函数
    void loadList(
      String key,
      List<dynamic> list,
      Function(Map<String, dynamic>) fromJson,
    ) {
      String? jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        list.clear();
        list.addAll((jsonDecode(jsonStr) as List).map((e) => fromJson(e)));
      }
    }

    // 加载普通任务
    loadList('timerTasks', _timerTasks, (e) => TaskItem.fromJson(e));
    loadList('dailyTasks', _dailyTasks, (e) => TaskItem.fromJson(e));
    loadList('normalTasks', _normalTasks, (e) => TaskItem.fromJson(e));

    // 加载周期任务
    loadList('cycleTasks', _cycleTasks, (e) => CycleTask.fromJson(e));
    // 每次启动重新计算一次周期时间，防止过期
    _recalcAllCycles();

    // 跨天重置逻辑
    if (lastOpenDate != todayStr) {
      for (var t in _dailyTasks) {
        t.isCompleted = false;
      }
      for (var t in _timerTasks) {
        t.durationSeconds = 0; // 重置专注时长
      }
      prefs.setString('lastOpenDate', todayStr);
      _saveData();
    }
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      'timerTasks',
      jsonEncode(_timerTasks.map((e) => e.toJson()).toList()),
    );
    prefs.setString(
      'dailyTasks',
      jsonEncode(_dailyTasks.map((e) => e.toJson()).toList()),
    );
    prefs.setString(
      'normalTasks',
      jsonEncode(_normalTasks.map((e) => e.toJson()).toList()),
    );
    prefs.setString(
      'cycleTasks',
      jsonEncode(_cycleTasks.map((e) => e.toJson()).toList()),
    );
    prefs.setString(
      'lastOpenDate',
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

  // ==================== 专注计时逻辑 (Timer) ====================

  void addTimerTask(String title, TimerMode mode, int? target) {
    _timerTasks.add(
      TaskItem(
        id: const Uuid().v4(),
        title: title,
        type: TaskType.timer,
        timerMode: mode,
        targetSeconds: target,
        colorIndex: _timerTasks.length % taskColors.length,
      ),
    );
    _saveData();
    notifyListeners();
  }

  void renameTimerTask(String id, String newName) {
    final index = _timerTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timerTasks[index].title = newName;
      _saveData();
      notifyListeners();
    }
  }

  void resetTimerTask(String id) {
    final index = _timerTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (_activeTimerId == id) stopTimer();
      _timerTasks[index].durationSeconds = 0;
      _saveData();
      notifyListeners();
    }
  }

  void deleteTimerTask(String id) {
    if (_activeTimerId == id) stopTimer();
    _timerTasks.removeWhere((t) => t.id == id);
    _saveData();
    notifyListeners();
  }

  void toggleTimer(String id) {
    if (_activeTimerId == id) {
      stopTimer();
    } else {
      stopTimer(); // 停止旧的
      _startTimer(id); // 启动新的
    }
  }

  void _startTimer(String id) async {
    _activeTimerId = id;

    // 1. 开启屏幕常亮
    WakelockPlus.enable();

    // 2. 启动前台服务 (后台保活)
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      service.startService();
    }

    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int index = _timerTasks.indexWhere((t) => t.id == id);
      if (index == -1) {
        stopTimer();
        return;
      }
      var task = _timerTasks[index];

      if (task.timerMode == TimerMode.stopwatch) {
        task.durationSeconds++;
      } else {
        if (task.durationSeconds < (task.targetSeconds ?? 0)) {
          task.durationSeconds++;
          if (task.durationSeconds >= (task.targetSeconds ?? 0)) {
            stopTimer();
            _playAlarm();
          }
        }
      }
      // 减少 I/O 频率，每5秒存一次
      if (task.durationSeconds % 5 == 0) _saveData();
      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _activeTimerId = null;

    // 1. 关闭屏幕常亮
    WakelockPlus.disable();

    // 2. 停止前台服务
    final service = FlutterBackgroundService();
    service.invoke("stopService");

    _saveData();
    notifyListeners();
  }

  void _playAlarm() {
    FlutterRingtonePlayer().playNotification(
      looping: false,
      volume: 1.0,
      asAlarm: true,
    );
    // 简单的震动反馈
    // HapticFeedback.heavyImpact();
  }

  // ==================== 待办清单逻辑 (Todo) ====================

  void addTodoTask(
    String title,
    TaskType type, {
    DateTime? deadline,
    List<String> tags = const [],
  }) {
    final t = TaskItem(
      id: const Uuid().v4(),
      title: title,
      type: type,
      deadline: deadline,
      tags: tags,
    );
    (type == TaskType.daily ? _dailyTasks : _normalTasks).add(t);
    _saveData();
    notifyListeners();
  }

  void updateTodoTask(
    TaskItem task,
    String newTitle,
    DateTime? newDeadline,
    List<String> newTags,
  ) {
    task.title = newTitle;
    task.deadline = newDeadline;
    task.tags = newTags;
    _saveData();
    notifyListeners();
  }

  void toggleTodo(TaskItem t) {
    t.isCompleted = !t.isCompleted;
    t.finishedAt = t.isCompleted ? DateTime.now() : null;
    _saveData();
    notifyListeners();
  }

  void deleteTodo(TaskItem t) {
    (t.type == TaskType.daily ? _dailyTasks : _normalTasks).removeWhere(
      (x) => x.id == t.id,
    );
    _saveData();
    notifyListeners();
  }

  void clearTodos({required bool completedOnly}) {
    _dailyTasks.removeWhere((t) => t.isCompleted == completedOnly);
    _normalTasks.removeWhere((t) => t.isCompleted == completedOnly);
    _saveData();
    notifyListeners();
  }

  // ==================== 周期提醒逻辑 (Cycle) ====================

  void addCycleTask(
    String title,
    CycleFrequency freq,
    DateTime time,
    int? val,
  ) {
    DateTime next = _calculateNextRun(freq, time, val);
    _cycleTasks.add(
      CycleTask(
        id: const Uuid().v4(),
        title: title,
        frequency: freq,
        time: time,
        specificValue: val,
        nextRunTime: next,
      ),
    );
    _sortCycles();
    _saveData();
    notifyListeners();
  }

  void updateCycleTask(
    CycleTask task,
    String title,
    CycleFrequency freq,
    DateTime time,
    int? val,
  ) {
    task.title = title;
    task.frequency = freq;
    task.time = time;
    task.specificValue = val;
    task.nextRunTime = _calculateNextRun(freq, time, val);
    _sortCycles();
    _saveData();
    notifyListeners();
  }

  void deleteCycleTask(String id) {
    _cycleTasks.removeWhere((t) => t.id == id);
    _saveData();
    notifyListeners();
  }

  // 核心算法：计算下一次提醒时间
  DateTime _calculateNextRun(CycleFrequency freq, DateTime time, int? val) {
    DateTime now = DateTime.now();
    DateTime target = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    switch (freq) {
      case CycleFrequency.daily:
        // 如果今天的这个时间已经过了，就推到明天
        if (target.isBefore(now)) target = target.add(const Duration(days: 1));
        break;

      case CycleFrequency.weekly: // val 代表周几 (1=周一, 7=周日)
        int diff = (val ?? 1) - now.weekday;
        if (diff < 0 || (diff == 0 && target.isBefore(now))) {
          // 如果目标周几比今天小，或者虽然是今天但时间过了，就推到下周
          diff += 7;
        }
        target = target.add(Duration(days: diff));
        break;

      case CycleFrequency.monthly: // val 代表几号 (1-31)
        // 先设为本月的这一天
        // 注意处理月份天数溢出（比如2月30日），DateTime会自动处理为3月2日，这里简化处理
        target = DateTime(
          now.year,
          now.month,
          val ?? 1,
          time.hour,
          time.minute,
        );
        if (target.isBefore(now)) {
          // 如果本月时间已过，推到下个月
          target = DateTime(
            now.year,
            now.month + 1,
            val ?? 1,
            time.hour,
            time.minute,
          );
        }
        break;

      case CycleFrequency.yearly: // time 中包含了设定的月份和日期
        target = DateTime(
          now.year,
          time.month,
          time.day,
          time.hour,
          time.minute,
        );
        if (target.isBefore(now)) {
          // 如果今年时间已过，推到明年
          target = DateTime(
            now.year + 1,
            time.month,
            time.day,
            time.hour,
            time.minute,
          );
        }
        break;
    }
    return target;
  }

  void _sortCycles() {
    // 按下次执行时间升序排列
    _cycleTasks.sort((a, b) => a.nextRunTime.compareTo(b.nextRunTime));
  }

  void _recalcAllCycles() {
    for (var t in _cycleTasks) {
      t.nextRunTime = _calculateNextRun(t.frequency, t.time, t.specificValue);
    }
    _sortCycles();
  }
}
