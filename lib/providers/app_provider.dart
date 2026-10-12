import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/task_model.dart';
import '../models/journal_entry.dart';

import '../utils/schedule.dart';

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = [];
  List<TaskCollection> _collections = [];
  final List<JournalEntry> _journalEntries = [];
  final List<JournalCollection> _journalCollections = [];
  List<JournalCollection> get journalCollections => List.unmodifiable(
    List<JournalCollection>.from(_journalCollections)..sort((a, b) {
      DateTime edited(JournalCollection c) => _journalEntries
          .where((e) => e.collectionId == c.id)
          .fold(
            c.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            (latest, e) => e.updatedAt.isAfter(latest) ? e.updatedAt : latest,
          );
      final result = edited(b).compareTo(edited(a));
      return result != 0
          ? result
          : _journalCollections
                .indexOf(a)
                .compareTo(_journalCollections.indexOf(b));
    }),
  );

  Future<void> addJournalCollection(String title) async {
    await ready;
    if (title.trim().isEmpty) return;
    final next = [
      ..._journalCollections,
      JournalCollection(
        id: const Uuid().v4(),
        title: title.trim(),
        updatedAt: DateTime.now(),
      ),
    ];
    await _persistJournalCollections(next);
  }

  Future<void> renameJournalCollection(String id, String title) async {
    await ready;
    if (title.trim().isEmpty) return;
    await _persistJournalCollections(
      _journalCollections
          .map(
            (c) => c.id == id
                ? JournalCollection(
                    id: id,
                    title: title.trim(),
                    updatedAt: DateTime.now(),
                  )
                : c,
          )
          .toList(),
    );
  }

  Future<void> removeJournalCollection(
    String id, {
    bool deleteEntries = false,
  }) async {
    await ready;
    if (!_journalCollections.any((c) => c.id == id)) return;
    // Save notes before removing the folder so a failed write never strands them.
    await _persistJournal(
      deleteEntries
          ? _journalEntries.where((e) => e.collectionId != id).toList()
          : _journalEntries
                .map(
                  (e) => e.collectionId == id
                      ? e.copyWith(collectionId: null, move: true)
                      : e,
                )
                .toList(),
    );
    await _persistJournalCollections(
      _journalCollections.where((c) => c.id != id).toList(),
    );
  }

  Future<void> _persistJournalCollections(
    List<JournalCollection> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'journal_collections',
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    )) {
      throw StateError('合集保存失败');
    }
    _journalCollections
      ..clear()
      ..addAll(entries);
    if (!_disposed) notifyListeners();
  }

  Future<void> _journalWrite = Future.value();
  List<JournalEntry> get journalEntries => List.unmodifiable(
    List<JournalEntry>.from(_journalEntries)..sort(
      (a, b) => a.isPinned != b.isPinned
          ? (a.isPinned ? -1 : 1)
          : a.isBottom != b.isBottom
          ? (a.isBottom ? 1 : -1)
          : b.updatedAt.compareTo(a.updatedAt),
    ),
  );

  Future<void> saveJournalEntry(JournalEntry entry) async {
    await ready;
    final next = List<JournalEntry>.from(_journalEntries);
    final index = next.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      next.add(entry);
    } else {
      next[index] = entry;
    }
    await _persistJournal(next);
  }

  Future<void> removeJournalEntry(String id) async {
    await ready;
    await _persistJournal(_journalEntries.where((e) => e.id != id).toList());
  }

  Future<void> _persistJournal(List<JournalEntry> entries) {
    // Serialize snapshots so rapid edits cannot overwrite a newer save.
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    _journalEntries
      ..clear()
      ..addAll(entries);
    if (!_disposed) notifyListeners();
    final write = _journalWrite.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('journal_entries', encoded)) {
        throw StateError('记录保存失败');
      }
    });
    _journalWrite = write.catchError((Object _) {});
    return write;
  }

  final List<CalendarCountdown> _countdowns = [];
  List<CalendarCountdown> get countdowns => List.unmodifiable(_countdowns);
  Timer? _maintenanceTimer;
  bool _disposed = false;
  bool _looseTasksFirst = true;
  bool _countdownsFirst = true;
  String _lastModule = 'todo';
  bool get countdownsFirst => _countdownsFirst;
  String get lastModule => _lastModule;

  Future<void> setCountdownsFirst(bool value) async {
    await ready;
    if (_disposed || _countdownsFirst == value) return;
    _countdownsFirst = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('countdowns_first', value);
  }

  Future<void> setLastModule(String value) async {
    if (!['todo', 'journal', 'calendar', 'settings'].contains(value)) return;
    await ready;
    _lastModule = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_module', value);
  }

  bool get looseTasksFirst => _looseTasksFirst;

  Future<void> setLooseTasksFirst(bool value) async {
    await ready;
    if (_disposed || _looseTasksFirst == value) return;
    _looseTasksFirst = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loose_tasks_first', value);
  }

  late final Future<void> ready;

  // Getters
  List<TaskItem> get dailyTasks => _dailyTasks;
  List<TaskItem> get normalTasks => _normalTasks;
  List<CycleTask> get cycleTasks => _cycleTasks;
  List<TaskCollection> get collections => _collections;

  List<TaskCollection> get orderedCollections {
    // Stable partition: deadline-bearing collections move ahead without
    // disturbing the user's existing order within either group.
    final withDeadline = _normalTasks
        .where((task) => !task.isCompleted && task.deadline != null)
        .map((task) => task.collectionId)
        .toSet();
    return [
      ..._collections.where((c) => withDeadline.contains(c.id)),
      ..._collections.where((c) => !withDeadline.contains(c.id)),
    ];
  }

  // 获取特定状态的日常打卡（用于批量删除）
  List<TaskItem> getDailyTasks({required bool isCompleted}) {
    return _dailyTasks.where((t) => t.isCompleted == isCompleted).toList();
  }

  // 根据完成状态过滤合集中的事项
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

  // 根据完成状态过滤散落事项
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
    }
  }

  Future<void> _initData() async {
    await _loadData();
    if (_disposed) return;
    _maintainData();
    _maintenanceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _maintainData(),
    );
    notifyListeners();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _looseTasksFirst = prefs.getBool('loose_tasks_first') ?? true;
    _countdownsFirst = prefs.getBool('countdowns_first') ?? true;
    final module = prefs.getString('last_module');
    _lastModule = ['todo', 'journal', 'calendar', 'settings'].contains(module)
        ? module!
        : 'todo';
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
    // Discard only the withdrawn backup build's cache; keep the live data.
    await prefs.remove('local_backup_snapshot');
    safeLoad('daily_tasks', _dailyTasks, (json) => TaskItem.fromJson(json));
    safeLoad('normal_tasks', _normalTasks, (json) => TaskItem.fromJson(json));
    safeLoad('cycle_tasks', _cycleTasks, (json) => CycleTask.fromJson(json));
    safeLoad('journal_entries', _journalEntries, JournalEntry.fromJson);
    safeLoad(
      'journal_collections',
      _journalCollections,
      JournalCollection.fromJson,
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

  String exportData() {
    final data = {
      'journal_entries': _journalEntries.map((e) => e.toJson()).toList(),
      'journal_collections': _journalCollections
          .map((e) => e.toJson())
          .toList(),
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
        'calendar_countdowns',
        'journal_entries',
        'journal_collections',
      ].any(data.containsKey)) {
        return false;
      }
      final daily = parse('daily_tasks', TaskItem.fromJson, _dailyTasks);
      final entries = parse(
        'journal_entries',
        JournalEntry.fromJson,
        _journalEntries,
      );
      final journalCollections = parse(
        'journal_collections',
        JournalCollection.fromJson,
        _journalCollections,
      );
      final normal = parse('normal_tasks', TaskItem.fromJson, _normalTasks);
      final cycles = parse('cycle_tasks', CycleTask.fromJson, _cycleTasks);
      final collections = parse(
        'collections',
        TaskCollection.fromJson,
        _collections,
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
      _countdowns
        ..clear()
        ..addAll(countdowns);
      _maintainData();
      await _saveData();
      if (data.containsKey('journal_entries')) await _persistJournal(entries);
      if (data.containsKey('journal_collections')) {
        await _persistJournalCollections(journalCollections);
      }
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
    _normalTasks.removeWhere((task) => task.collectionId == collectionId);
    _collections.removeWhere((c) => c.id == collectionId);
    _saveData();
    notifyListeners();
  }

  void renameCollection(String id, String title) {
    final index = _collections.indexWhere((item) => item.id == id);
    if (index == -1 || title.trim().isEmpty) return;
    _collections[index].title = title.trim();
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

  // 删除所有合集及其中的已完成、未完成事项。
  void clearCollections() {
    _normalTasks.removeWhere((task) => task.collectionId != null);
    _collections.clear();
    _saveData();
    notifyListeners();
  }

  // 清空散落事项 (根据状态)
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
    _saveData();
    notifyListeners();
  }

  void updateCycleTask(
    CycleTask task,
    String title,
    CycleFrequency frequency,
    DateTime time, {
    required bool allDay,
  }) {
    task.title = title;
    task.frequency = frequency;
    task.time = time;
    task.allDay = allDay;
    task.nextRunTime = nextOccurrence(time, frequency, DateTime.now());
    _saveData();
    notifyListeners();
  }

  void updateCountdown(
    CalendarCountdown task,
    String title,
    DateTime deadline, {
    bool? allDay,
  }) {
    final index = _countdowns.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    _countdowns[index] = CalendarCountdown(
      id: task.id,
      title: title,
      deadline: deadline,
      allDay: allDay ?? task.allDay,
    );
    _saveData();
    notifyListeners();
  }

  void removeCycleTask(CycleTask task) {
    _cycleTasks.remove(task);
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

  void addCountdown(String title, DateTime deadline, {bool allDay = false}) {
    _countdowns.add(
      CalendarCountdown(
        id: const Uuid().v4(),
        title: title,
        deadline: deadline,
        allDay: allDay,
      ),
    );
    _saveData();
    notifyListeners();
  }

  void removeCountdown(CalendarCountdown task) {
    _countdowns.remove(task);
    _saveData();
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
    }
    final before = _normalTasks.length;
    _normalTasks.removeWhere(
      (t) =>
          t.isCompleted &&
          t.finishedAt != null &&
          now.difference(t.finishedAt!) >= const Duration(days: 7),
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
    notifyListeners();
  }

  void toggleTaskCompletion(TaskItem task) {
    task.isCompleted = !task.isCompleted;
    task.finishedAt = task.isCompleted ? DateTime.now() : null;
    _saveData();
    notifyListeners();
  }
}
