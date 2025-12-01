import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';

class AppProvider with ChangeNotifier {
  final List<TaskItem> _timerTasks = [];
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];

  Timer? _timer;
  String? _activeTimerId;

  List<TaskItem> get timerTasks => _timerTasks;
  List<TaskItem> get dailyTasks => _dailyTasks;
  List<TaskItem> get normalTasks => _normalTasks;
  String? get activeTimerId => _activeTimerId;

  AppProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastOpenDate = prefs.getString('lastOpenDate');
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    void loadList(String key, List<TaskItem> list) {
      String? jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        list.clear();
        list.addAll(
          (jsonDecode(jsonStr) as List).map((e) => TaskItem.fromJson(e)),
        );
      }
    }

    loadList('timerTasks', _timerTasks);
    loadList('dailyTasks', _dailyTasks);
    loadList('normalTasks', _normalTasks);

    if (lastOpenDate != todayStr) {
      for (var t in _dailyTasks) {
        t.isCompleted = false;
      }
      for (var t in _timerTasks) {
        t.durationSeconds = 0;
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
      'lastOpenDate',
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

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

  void clearAllTimerTasks() {
    stopTimer();
    _timerTasks.clear();
    _saveData();
    notifyListeners();
  }

  void toggleTimer(String id) {
    if (_activeTimerId == id) {
      stopTimer();
    } else {
      stopTimer();
      _startTimer(id);
    }
  }

  void _startTimer(String id) {
    _activeTimerId = id;
    WakelockPlus.enable();
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
      if (task.durationSeconds % 5 == 0) _saveData();
      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _activeTimerId = null;
    WakelockPlus.disable();
    _saveData();
    notifyListeners();
  }

  void _playAlarm() {
    FlutterRingtonePlayer().playNotification(
      looping: false,
      volume: 1.0,
      asAlarm: true,
    );
    HapticFeedback.heavyImpact();
  }

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
}
