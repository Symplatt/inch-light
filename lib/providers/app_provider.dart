import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/task_model.dart';

import '../services/reminder_service.dart';
import '../utils/schedule.dart';

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = [];
  List<TaskCollection> _collections = [];

  final List<JournalEntry> _journalEntries = [];
  final List<CalendarCountdown> _countdowns = [];
  List<JournalEntry> get journalEntries => List.unmodifiable(_journalEntries);
  List<CalendarCountdown> get countdowns => List.unmodifiable(_countdowns);
  Timer? _maintenanceTimer;
  bool _disposed = false;
  String? reminderError;
  int _lastPageIndex = 0;

  late final Future<void> ready;

  // Getters
  List<TaskItem> get dailyTasks => _dailyTasks;
  List<TaskItem> get normalTasks => _normalTasks;
  List<CycleTask> get cycleTasks => _cycleTasks;
  List<TaskCollection> get collections => _collections;
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
      if (a.isBottom != b.isBottom) return a.isBottom ? 1 : -1;
      bool hasDeadlineA = a.deadline != null;
      bool hasDeadlineB = b.deadline != null;
      if (hasDeadlineA && !hasDeadlineB) return -1;
      if (!hasDeadlineA && hasDeadlineB) return 1;
      if (hasDeadlineA && hasDeadlineB) {
        return a.deadline!.compareTo(b.deadline!);
      }
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
      if (a.isBottom != b.isBottom) return a.isBottom ? 1 : -1;
      bool hasDeadlineA = a.deadline != null;
      bool hasDeadlineB = b.deadline != null;
      if (hasDeadlineA && !hasDeadlineB) return -1;
      if (!hasDeadlineA && hasDeadlineB) return 1;
      if (hasDeadlineA && hasDeadlineB) {
        return a.deadline!.compareTo(b.deadline!);
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return tasks;
  }

  AppProvider() {
    ready = _initData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _maintenanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maintainData();
      _syncReminders();
    }
  }

  Future<void> _initData() async {
    await _loadData();
    if (_disposed) return;
    _maintainData();
    _syncReminders();
    _maintenanceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _maintainData(),
    );
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

    await prefs.remove('timer_tasks');
    safeLoad('daily_tasks', _dailyTasks, (json) => TaskItem.fromJson(json));
    safeLoad('normal_tasks', _normalTasks, (json) => TaskItem.fromJson(json));
    safeLoad('cycle_tasks', _cycleTasks, (json) => CycleTask.fromJson(json));
    safeLoad(
      'journal_entries',
      _journalEntries,
      (json) => JournalEntry.fromJson(json),
    );
    safeLoad(
      'calendar_countdowns',
      _countdowns,
      (json) => CalendarCountdown.fromJson(json),
    );
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
    await prefs.setString('daily_tasks', encode(_dailyTasks));
    await prefs.setString('normal_tasks', encode(_normalTasks));
    await prefs.setString('cycle_tasks', encode(_cycleTasks));
    await prefs.setString('collections_data', encode(_collections));
    await prefs.setString('journal_entries', encode(_journalEntries));
    await prefs.setString('calendar_countdowns', encode(_countdowns));
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
      if (hasChanges && !_disposed) {
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
      'journal_entries': _journalEntries.map((e) => e.toJson()).toList(),
      'calendar_countdowns': _countdowns.map((e) => e.toJson()).toList(),
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
      // Parse all sections first: malformed backups must never partially replace data.
      List<T> parse<T>(
        String key,
        T Function(Map<String, dynamic>) parser,
        List<T> fallback,
      ) => data[key] == null
          ? List<T>.from(fallback)
          : (data[key] as List)
                .map((e) => parser(Map<String, dynamic>.from(e)))
                .toList();
      if (![
        'daily_tasks',
        'normal_tasks',
        'cycle_tasks',
        'collections',
        'journal_entries',
        'calendar_countdowns',
      ].any(data.containsKey)) {
        return false;
      }
      final daily = parse('daily_tasks', TaskItem.fromJson, _dailyTasks);
      final normal = parse('normal_tasks', TaskItem.fromJson, _normalTasks);
      final cycles = parse('cycle_tasks', CycleTask.fromJson, _cycleTasks);
      final collections = parse(
        'collections',
        TaskCollection.fromJson,
        _collections,
      );
      final entries = parse(
        'journal_entries',
        JournalEntry.fromJson,
        _journalEntries,
      );
      final countdowns = parse(
        'calendar_countdowns',
        CalendarCountdown.fromJson,
        _countdowns,
      );
      _dailyTasks
        ..clear()
        ..addAll(daily);
      _normalTasks
        ..clear()
        ..addAll(normal);
      _cycleTasks
        ..clear()
        ..addAll(cycles);
      _collections = collections;
      _journalEntries
        ..clear()
        ..addAll(entries);
      _countdowns
        ..clear()
        ..addAll(countdowns);
      _maintainData();
      _syncReminders();
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
    if (task.type == TaskType.daily) _dailyTasks.remove(task);
    if (task.type == TaskType.normal) _normalTasks.remove(task);
    _saveData();
    notifyListeners();
  }

  void addCycleTask(
    String title,
    CycleFrequency frequency,
    DateTime time, {
    bool allDay = false,
  }) {
    _cycleTasks.add(
      CycleTask(
        id: const Uuid().v4(),
        title: title,
        frequency: frequency,
        time: time,
        nextRunTime: nextOccurrence(time, frequency, DateTime.now()),
        allDay: allDay,
      ),
    );
    _syncReminders();
    _saveData();
    notifyListeners();
  }

  void removeCycleTask(CycleTask task) {
    _cycleTasks.remove(task);
    _syncReminders();
    _saveData();
    notifyListeners();
  }

  DateTime? nearestDeadline(String collectionId) {
    final dates =
        _normalTasks
            .where(
              (t) =>
                  t.collectionId == collectionId &&
                  !t.isCompleted &&
                  t.deadline != null,
            )
            .map((t) => t.deadline!)
            .toList()
          ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  void completeCollection(String id) {
    final now = DateTime.now();
    for (final task in _normalTasks.where(
      (t) => t.collectionId == id && !t.isCompleted,
    )) {
      task.isCompleted = true;
      task.finishedAt = now;
    }
    _saveData();
    notifyListeners();
  }

  void clearCollectionTasks(String id) {
    _normalTasks.removeWhere((t) => t.collectionId == id);
    _saveData();
    notifyListeners();
  }

  void setTaskPosition(TaskItem task, int position) {
    task.isPinned = position < 0;
    task.isBottom = position > 0;
    _saveData();
    notifyListeners();
  }

  void addJournalEntry(String content, DateTime capturedAt) {
    if (content.trim().isEmpty) return;
    _journalEntries.add(
      JournalEntry(
        id: const Uuid().v4(),
        content: content.trim(),
        createdAt: capturedAt,
      ),
    );
    _saveData();
    notifyListeners();
  }

  void addCountdown(String title, DateTime deadline) {
    _countdowns.add(
      CalendarCountdown(
        id: const Uuid().v4(),
        title: title,
        deadline: deadline,
      ),
    );
    _saveData();
    _syncReminders();
    notifyListeners();
  }

  void removeCountdown(CalendarCountdown task) {
    _countdowns.remove(task);
    _saveData();
    _syncReminders();
    notifyListeners();
  }

  DateTime? _lastMaintenanceDay;
  void _maintainData() {
    if (_disposed) return;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    if (_lastMaintenanceDay != day) {
      _lastMaintenanceDay = day;
      _checkAndResetDailyTasks();
      _syncReminders();
    }
    final before = _normalTasks.length;
    _normalTasks.removeWhere(
      (t) =>
          t.isCompleted &&
          t.finishedAt != null &&
          now.difference(t.finishedAt!) > const Duration(days: 1),
    );
    bool changed = before != _normalTasks.length;
    bool cyclesChanged = false;
    for (final task in _cycleTasks) {
      if (!task.nextRunTime.isAfter(now)) {
        task.nextRunTime = nextOccurrence(task.time, task.frequency, now);
        cyclesChanged = true;
      }
    }
    if (changed || cyclesChanged) _saveData();
    if (cyclesChanged) _syncReminders();
    notifyListeners();
  }

  Future<void> _syncReminders() async {
    try {
      await ReminderService.instance.sync(
        List.of(_cycleTasks),
        List.of(_countdowns),
      );
      reminderError = null;
    } catch (e) {
      reminderError = '提醒未能安排，请检查系统通知权限后重新打开应用';
      debugPrint('Reminder scheduling failed: $e');
    }
    if (!_disposed) notifyListeners();
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
}
