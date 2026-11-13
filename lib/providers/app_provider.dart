import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/task_model.dart';
import '../models/journal_entry.dart';
import '../models/work_log.dart';
import '../models/meal_menu.dart';
import '../models/project_updates.dart';
import '../models/academic_peers.dart';
import '../models/last_time.dart';

import '../utils/schedule.dart';
import '../utils/backup_preferences.dart';
import '../utils/journal_sort.dart';

export '../utils/journal_sort.dart' show JournalSort;

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  bool _backupReady = false;
  SharedPreferences? _preferences;
  Set<String> _seenCalendarAlerts = {};
  String? _backupSnapshot;
  String? _backupDay;
  Future<void> _backupWrite = Future.value();
  Timer? _backupTimer;
  List<JournalEntry>? _sortedJournalEntries;
  List<JournalCollection>? _sortedJournalCollections;

  @override
  void notifyListeners() {
    _sortedJournalEntries = null;
    _sortedJournalCollections = null;
    super.notifyListeners();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // Coalesce rapid edits after the input frame instead of encoding the entire
    // library synchronously inside every listener notification.
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(milliseconds: 700), _syncBackup);
  }

  void _syncBackup() {
    if (!_backupReady ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final snapshot = exportData();
    final day = DateTime.now().toIso8601String().split('T').first;
    if (snapshot == _backupSnapshot && day == _backupDay) return;
    _backupSnapshot = snapshot;
    _backupDay = day;
    // Serialize complete snapshots; the background job never reads partially saved sections.
    _backupWrite = _backupWrite.then((_) async {
      try {
        await const MethodChannel(
          'inch_light/data_export',
        ).invokeMethod<void>('syncBackup', {'data': snapshot});
      } catch (_) {
        _backupSnapshot = null;
        _backupDay = null;
      }
    });
  }

  final List<TaskItem> _dailyTasks = [];
  final List<TaskItem> _normalTasks = [];
  final List<CycleTask> _cycleTasks = [];
  List<TaskCollection> _collections = [];
  Set<String> _hiddenTodoCollections = {};
  bool isTodoCollectionVisible(String id) =>
      !_hiddenTodoCollections.contains(id);

  Future<void> setVisibleTodoCollections(Set<String> ids) async {
    final hidden = _collections
        .where((c) => !ids.contains(c.id))
        .map((c) => c.id)
        .toSet();
    _hiddenTodoCollections = hidden;
    await _saveData();
    notifyListeners();
  }

  final List<JournalEntry> _journalEntries = [];
  final List<JournalCollection> _journalCollections = [];
  JournalSort _journalCollectionSort = JournalSort.edited;
  JournalSort _journalEntrySort = JournalSort.edited;
  JournalSort get journalCollectionSort => _journalCollectionSort;
  JournalSort get journalEntrySort => _journalEntrySort;

  Future<void> setJournalSort(
    JournalSort value, {
    required bool collections,
  }) async {
    await ready;
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      collections ? 'journal_collection_sort' : 'journal_entry_sort',
      value.name,
    );
    if (!saved) throw StateError('Unable to save journal sort');
    if (collections) {
      _journalCollectionSort = value;
    } else {
      _journalEntrySort = value;
    }
    if (!_disposed) notifyListeners();
  }

  final Map<String, ({JournalEntry entry, DateTime deletedAt})>
  _recentlyDeleted = {};
  final DateTime Function() _journalNow;
  final DateTime Function() _now;
  DateTime get now => _now();
  late final ValueNotifier<DateTime> clock = ValueNotifier(now);
  bool _recoverable(DateTime deletedAt) {
    final age = _journalNow().difference(deletedAt);
    return !age.isNegative && age < const Duration(minutes: 1);
  }

  int get recoverableJournalCount => _recentlyDeleted.values
      .where((item) => _recoverable(item.deletedAt))
      .length;

  Future<int> restoreRecentJournalEntries() async {
    await ready;
    final restoring = _recentlyDeleted.values
        .where((item) => _recoverable(item.deletedAt))
        .toList();
    final next = List<JournalEntry>.from(_journalEntries);
    final added = <String>{};
    for (final item in restoring) {
      if (next.any((e) => e.id == item.entry.id)) continue;
      final entry = item.entry;
      added.add(entry.id);
      next.add(
        entry.collectionId == null ||
                _journalCollections.any((c) => c.id == entry.collectionId)
            ? entry
            : entry.copyWith(collectionId: null, move: true),
      );
    }
    // Persist the restored notes before discarding the recovery copies.
    try {
      await _persistJournal(next);
    } catch (_) {
      _journalEntries.removeWhere((e) => added.contains(e.id));
      if (!_disposed) notifyListeners();
      rethrow;
    }
    for (final item in restoring) {
      _recentlyDeleted.remove(item.entry.id);
    }
    if (!_disposed) notifyListeners();
    return restoring.length;
  }

  List<JournalCollection> get journalCollections {
    if (_sortedJournalCollections != null) return _sortedJournalCollections!;
    final names = _journalCollectionSort == JournalSort.name
        ? {for (final c in _journalCollections) c.id: JournalNameKey(c.title)}
        : <String, JournalNameKey>{};
    final indices = {
      for (var i = 0; i < _journalCollections.length; i++)
        _journalCollections[i].id: i,
    };
    final edited = {
      for (final c in _journalCollections)
        c.id: c.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    };
    for (final entry in _journalEntries) {
      final previous = edited[entry.collectionId];
      if (previous != null && entry.updatedAt.isAfter(previous)) {
        edited[entry.collectionId!] = entry.updatedAt;
      }
    }
    return _sortedJournalCollections = List.unmodifiable(
      List<JournalCollection>.from(_journalCollections)..sort((a, b) {
        if (_journalCollectionSort == JournalSort.name) {
          final result = names[a.id]!.compareTo(names[b.id]!);
          if (result != 0) return result;
          return indices[a.id]!.compareTo(indices[b.id]!);
        }
        final result = edited[b.id]!.compareTo(edited[a.id]!);
        return result != 0 ? result : indices[a.id]!.compareTo(indices[b.id]!);
      }),
    );
  }

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
  List<JournalEntry> get journalEntries {
    if (_sortedJournalEntries != null) return _sortedJournalEntries!;
    final names = _journalEntrySort == JournalSort.name
        ? {
            for (final e in _journalEntries)
              e.id: JournalNameKey(e.title.isEmpty ? '未命名' : e.title),
          }
        : <String, JournalNameKey>{};
    return _sortedJournalEntries = List.unmodifiable(
      List<JournalEntry>.from(_journalEntries)..sort(
        (a, b) => a.isPinned != b.isPinned
            ? (a.isPinned ? -1 : 1)
            : a.isBottom != b.isBottom
            ? (a.isBottom ? 1 : -1)
            : _journalEntrySort == JournalSort.name
            ? names[a.id]!.compareTo(names[b.id]!)
            : b.updatedAt.compareTo(a.updatedAt),
      ),
    );
  }

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

  Future<void> removeJournalEntry(String id, {bool recoverable = false}) async {
    await ready;
    final matches = _journalEntries.where((e) => e.id == id);
    if (matches.isEmpty) return;
    final entry = matches.first;
    if (recoverable) {
      _recentlyDeleted[id] = (entry: entry, deletedAt: _journalNow());
    }
    try {
      await _persistJournal(_journalEntries.where((e) => e.id != id).toList());
    } catch (_) {
      _recentlyDeleted.remove(id);
      if (!_journalEntries.any((e) => e.id == id)) _journalEntries.add(entry);
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  Future<void> moveJournalEntries(Set<String> ids, String? collectionId) async {
    await ready;
    if (collectionId != null &&
        !_journalCollections.any((c) => c.id == collectionId)) {
      throw StateError('合集不存在');
    }
    final before = {for (final entry in _journalEntries) entry.id: entry};
    try {
      await _persistJournal(
        _journalEntries
            .map(
              (entry) => ids.contains(entry.id)
                  ? entry.copyWith(collectionId: collectionId, move: true)
                  : entry,
            )
            .toList(),
      );
    } catch (_) {
      for (var i = 0; i < _journalEntries.length; i++) {
        final entry = _journalEntries[i];
        if (ids.contains(entry.id) && before.containsKey(entry.id)) {
          _journalEntries[i] = before[entry.id]!;
        }
      }
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  Future<void> removeJournalEntries(Set<String> ids) async {
    await ready;
    final before = List<JournalEntry>.from(_journalEntries);
    try {
      await _persistJournal(
        _journalEntries.where((e) => !ids.contains(e.id)).toList(),
      );
    } catch (_) {
      for (final entry in before.where((e) => ids.contains(e.id))) {
        if (!_journalEntries.any((e) => e.id == entry.id)) {
          _journalEntries.add(entry);
        }
      }
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  Future<void> _persistJournal(List<JournalEntry> entries) {
    // Serialize snapshots so rapid edits cannot overwrite a newer save.
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    final recent = jsonEncode(
      _recentlyDeleted.values
          .where((item) => _recoverable(item.deletedAt))
          .map(
            (item) => {
              'entry': item.entry.toJson(),
              'deletedAt': item.deletedAt.toIso8601String(),
            },
          )
          .toList(),
    );
    _journalEntries
      ..clear()
      ..addAll(entries);
    if (!_disposed) notifyListeners();
    final write = _journalWrite.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('journal_recently_deleted', recent)) {
        throw StateError('恢复记录保存失败');
      }
      if (!await prefs.setString('journal_entries', encoded)) {
        throw StateError('记录保存失败');
      }
    });
    _journalWrite = write.catchError((Object _) {});
    return write;
  }

  final List<CalendarCountdown> _countdowns = [];
  MealData _meals = MealData.empty();
  MealData get meals => _meals;
  Future<void> _mealWrite = Future.value();

  Future<void> updateMeals(MealData Function(MealData) update) {
    final write = _mealWrite.then((_) async {
      await ready;
      final next = update(_meals);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('meal_menus', jsonEncode(next.toJson()))) {
        throw StateError('菜单保存失败，请重试');
      }
      _meals = next;
      notifyListeners();
    });
    _mealWrite = write.catchError((Object _) {});
    return write;
  }

  ProjectUpdatesData _projectUpdates = ProjectUpdatesData.empty();
  ProjectUpdatesData get projectUpdates => _projectUpdates;
  Future<void> _projectUpdatesWrite = Future.value();

  Future<void> updateProjectUpdates(ProjectUpdatesData Function(ProjectUpdatesData) update) {
    final write = _projectUpdatesWrite.then((_) async {
      await ready;
      final next = update(_projectUpdates);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('project_updates', jsonEncode(next.toJson()))) {
        throw StateError('项目更新保存失败，请重试');
      }
      _projectUpdates = next;
      notifyListeners();
    });
    _projectUpdatesWrite = write.catchError((Object _) {});
    return write;
  }

  AcademicPeersData _academicPeers = AcademicPeersData();
  AcademicPeersData get academicPeers => _academicPeers;
  Future<void> _academicPeersWrite = Future.value();

  Future<void> updateAcademicPeers(AcademicPeersData Function(AcademicPeersData) update) {
    final write = _academicPeersWrite.then((_) async {
      await ready;
      final next = update(_academicPeers);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('academic_peers', jsonEncode(next.toJson()))) {
        throw StateError('同门资料保存失败，请重试');
      }
      _academicPeers = next;
      notifyListeners();
    });
    _academicPeersWrite = write.catchError((Object _) {});
    return write;
  }

  LastTimeData _lastTime = LastTimeData();
  LastTimeData get lastTime => _lastTime;
  Future<void> _lastTimeWrite = Future.value();

  Future<void> updateLastTime(LastTimeData Function(LastTimeData) update) {
    final write = _lastTimeWrite.then((_) async {
      await ready;
      final next = update(_lastTime);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('last_time', jsonEncode(next.toJson()))) {
        throw StateError('事项保存失败，请重试');
      }
      _lastTime = next;
      notifyListeners();
    });
    _lastTimeWrite = write.catchError((Object _) {});
    return write;
  }

  WorkLogData _workLog = WorkLogData.empty();
  WorkLogData get workLog => _workLog;
  Future<void> _workLogWrite = Future.value();

  List<({String day, WorkLogItem item, int index, DateTime deletedAt})>
  _recentWorkLogDeletions = [];

  int get recoverableWorkLogCount =>
      _recentWorkLogDeletions.where((e) => _recoverable(e.deletedAt)).length;

  Future<int> restoreRecentWorkLogItems() async {
    var count = 0;
    await updateWorkLog((data) {
      var next = data;
      for (final entry in _recentWorkLogDeletions.reversed) {
        if (!_recoverable(entry.deletedAt) ||
            next.days.values
                .expand((items) => items)
                .any((item) => item.id == entry.item.id))
          continue;
        final items = [...?next.days[entry.day]];
        var item = entry.item;
        if (!data.columns.any((c) => c.id == item.columnId)) {
          final target = data.columns.firstWhere(
            (c) => item.columnId == 'skill'
                ? c.id == 'study' || c.name == '学习'
                : c.id == 'other' || c.name == '其他',
          );
          item = WorkLogItem(id: item.id, columnId: target.id, text: item.text);
        }
        items.insert(entry.index.clamp(0, items.length), item);
        next = WorkLogData(
          columns: next.columns,
          days: {...next.days, entry.day: items},
        );
        count++;
      }
      return next;
    });
    return count;
  }

  Future<void> updateWorkLog(
    WorkLogData Function(WorkLogData) update, {
    bool rememberDeletions = true,
  }) {
    // Live items and recovery copies share one atomic, serialized write.
    final write = _workLogWrite.then((_) async {
      await ready;
      final next = update(_workLog);
      final liveIds = next.days.values
          .expand((items) => items)
          .map((item) => item.id)
          .toSet();
      final recent = rememberDeletions
          ? _recentWorkLogDeletions
                .where(
                  (e) =>
                      _recoverable(e.deletedAt) && !liveIds.contains(e.item.id),
                )
                .toList()
          : <({String day, WorkLogItem item, int index, DateTime deletedAt})>[];
      if (rememberDeletions) {
        for (final day in _workLog.days.entries) {
          for (var index = day.value.length - 1; index >= 0; index--) {
            final item = day.value[index];
            if (!liveIds.contains(item.id))
              recent.add((
                day: day.key,
                item: item,
                index: index,
                deletedAt: _journalNow(),
              ));
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode({
        ...next.toJson(),
        'recentlyDeleted': [
          for (final entry in recent)
            {
              'day': entry.day,
              'item': entry.item.toJson(),
              'index': entry.index,
              'deletedAt': entry.deletedAt.toIso8601String(),
            },
        ],
      });
      if (!await prefs.setString('work_log', encoded))
        throw StateError('工作日志保存失败，请重试');
      _workLog = next;
      _recentWorkLogDeletions = recent;
      if (!_disposed) notifyListeners();
    });
    _workLogWrite = write.catchError((Object _) {});
    return write;
  }

  bool hasJournalEntry(String id) =>
      _journalEntries.any((entry) => entry.id == id);
  List<CalendarCountdown> get countdowns => List.unmodifiable(_countdowns);
  Timer? _maintenanceTimer;
  bool _disposed = false;
  bool _looseTasksFirst = true;
  bool _countdownsFirst = true;
  String _lastModule = 'todo';
  bool _autoOpenLastTool = false;
  String? _lastTool;
  bool get autoOpenLastTool => _autoOpenLastTool;
  String? get lastTool => _lastTool;

  Future<void> setAutoOpenLastTool(bool value) async {
    await ready;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool('auto_open_last_tool', value)) {
      throw StateError('Unable to save tool preference');
    }
    _autoOpenLastTool = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> setLastTool(String value) async {
    await ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_tool', value);
    _lastTool = value;
  }
  String? _lastJournalCollection;
  String? get lastJournalCollection =>
      _journalCollections.any((c) => c.id == _lastJournalCollection)
      ? _lastJournalCollection
      : null;

  Future<void> setLastJournalCollection(String? id) async {
    await ready;
    _lastJournalCollection = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('last_journal_collection');
    } else {
      await prefs.setString('last_journal_collection', id);
    }
  }

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
    if (!['todo', 'journal', 'calendar', 'tools', 'settings'].contains(value)) {
      return;
    }
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

  AppProvider({DateTime Function()? journalNow, DateTime Function()? now})
    : _journalNow = journalNow ?? now ?? DateTime.now,
      _now = now ?? DateTime.now {
    ready = _initData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _maintenanceTimer?.cancel();
    _backupTimer?.cancel();
    clock.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maintainData();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _backupTimer?.cancel();
      _syncBackup();
    }
  }

  Future<void> _initData() async {
    await _loadData();
    if (_disposed) return;
    _backupReady = true;
    _maintainData();
    _maintenanceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _maintainData(),
    );
    notifyListeners();
  }

  void _loadPreferences(SharedPreferences prefs) {
    _hiddenTodoCollections =
        (prefs.getStringList('hidden_todo_collections') ?? []).toSet();
    _looseTasksFirst = prefs.getBool('loose_tasks_first') ?? true;
    _countdownsFirst = prefs.getBool('countdowns_first') ?? true;
    _autoOpenLastTool = prefs.getBool('auto_open_last_tool') ?? false;
    _lastTool = prefs.getString('last_tool');
    _journalCollectionSort =
        prefs.getString('journal_collection_sort') == 'name'
        ? JournalSort.name
        : JournalSort.edited;
    _journalEntrySort = prefs.getString('journal_entry_sort') == 'name'
        ? JournalSort.name
        : JournalSort.edited;
    _lastJournalCollection = prefs.getString('last_journal_collection');
    final module = prefs.getString('last_module');
    _lastModule =
        ['todo', 'journal', 'calendar', 'tools', 'settings'].contains(module)
        ? module!
        : 'todo';
    _seenCalendarAlerts =
        (prefs.getStringList('calendar_seen_alerts') ??
                calendarAlertIds.toList())
            .toSet();
  }

  Set<String> get calendarAlertIds {
    final time = now;
    bool urgent(DateTime due) =>
        due.isAfter(time) && due.difference(time) <= const Duration(hours: 24);
    return {
      for (final task in _countdowns)
        if (urgent(task.deadline))
          'countdown:${task.id}:${task.deadline.millisecondsSinceEpoch}',
      for (final task in _cycleTasks)
        if (urgent(task.nextRunTime))
          'cycle:${task.id}:${task.nextRunTime.millisecondsSinceEpoch}',
    };
  }

  bool get hasCalendarAlerts => calendarAlertIds.isNotEmpty;
  bool get hasNewCalendarAlerts =>
      calendarAlertIds.any((id) => !_seenCalendarAlerts.contains(id));
  Future<void> markCalendarAlertsSeen() async {
    _seenCalendarAlerts = calendarAlertIds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'calendar_seen_alerts',
      _seenCalendarAlerts.toList(),
    );
    notifyListeners();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    _loadPreferences(prefs);
    final mealJson = prefs.getString('meal_menus');
    if (mealJson != null) _meals = MealData.fromJson(jsonDecode(mealJson) as Map<String, dynamic>);
    final projectUpdatesJson = prefs.getString('project_updates');
    if (projectUpdatesJson != null) {
      _projectUpdates = ProjectUpdatesData.fromJson(jsonDecode(projectUpdatesJson) as Map<String, dynamic>);
    }
    final academicPeersJson = prefs.getString('academic_peers');
    if (academicPeersJson != null) {
      _academicPeers = AcademicPeersData.fromJson(jsonDecode(academicPeersJson) as Map<String, dynamic>);
    }
    final lastTimeJson = prefs.getString('last_time');
    if (lastTimeJson != null) {
      _lastTime = LastTimeData.fromJson(jsonDecode(lastTimeJson) as Map<String, dynamic>);
    }
    final workLogJson = prefs.getString('work_log');
    if (workLogJson != null) {
      _workLog = WorkLogData.fromJson(
        jsonDecode(workLogJson) as Map<String, dynamic>,
      );
      final saved = jsonDecode(workLogJson) as Map<String, dynamic>;
      for (final raw in saved['recentlyDeleted'] as List? ?? const []) {
        try {
          final deletedAt = DateTime.parse(raw['deletedAt'] as String);
          if (_recoverable(deletedAt)) {
            _recentWorkLogDeletions.add((
              day: raw['day'] as String,
              item: WorkLogItem.fromJson(
                Map<String, dynamic>.from(raw['item'] as Map),
              ),
              index: raw['index'] as int,
              deletedAt: deletedAt,
            ));
          }
        } catch (_) {
          // An invalid recovery copy must not block loading live items.
        }
      }
    }
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
    try {
      final recent =
          jsonDecode(prefs.getString('journal_recently_deleted') ?? '[]')
              as List;
      for (final item in recent) {
        final entry = JournalEntry.fromJson(
          Map<String, dynamic>.from(item['entry'] as Map),
        );
        final deletedAt = DateTime.parse(item['deletedAt'] as String);
        if (_recoverable(deletedAt) &&
            !_journalEntries.any((e) => e.id == entry.id)) {
          _recentlyDeleted[entry.id] = (entry: entry, deletedAt: deletedAt);
        }
      }
    } catch (e) {
      debugPrint('Error parsing recent journal deletions: $e');
    }
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
    if (!prefs.containsKey('calendar_seen_alerts')) {
      _seenCalendarAlerts = calendarAlertIds;
      await prefs.setStringList(
        'calendar_seen_alerts',
        _seenCalendarAlerts.toList(),
      );
    }
    await _checkAndResetDailyTasks();
  }

  Future<void> _taskWrite = Future.value();
  Future<void> _saveData() {
    String encode(List<dynamic> list) =>
        json.encode(list.map((e) => e.toJson()).toList());
    // Capture once before awaiting. Later edits queue behind this snapshot and
    // unchanged sections avoid a platform-channel/disk write altogether.
    final sections = {
      'daily_tasks': encode(_dailyTasks),
      'normal_tasks': encode(_normalTasks),
      'cycle_tasks': encode(_cycleTasks),
      'collections_data': encode(_collections),
      'calendar_countdowns': encode(_countdowns),
    };
    final hidden = _hiddenTodoCollections.toList();
    final write = _taskWrite.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      for (final section in sections.entries) {
        if (prefs.getString(section.key) != section.value &&
            !await prefs.setString(section.key, section.value)) {
          throw StateError('事项保存失败');
        }
      }
      if (!listEquals(prefs.getStringList('hidden_todo_collections'), hidden) &&
          !await prefs.setStringList('hidden_todo_collections', hidden)) {
        throw StateError('隐藏合集保存失败');
      }
    });
    _taskWrite = write.catchError((Object _) {});
    return write;
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
      'work_log': _workLog.toJson(),
      'meal_menus': _meals.toJson(),
      'project_updates': _projectUpdates.toJson(),
      'academic_peers': _academicPeers.toJson(),
      'last_time': _lastTime.toJson(),
      if (_preferences != null) 'preferences': backupPreferences(_preferences!),
    };
    return jsonEncode(data);
  }

  Future<bool> importData(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString.trim());
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
        'work_log',
        'meal_menus',
        'project_updates',
        'academic_peers',
        'last_time',
      ].any(data.containsKey)) {
        return false;
      }
      final meals = data.containsKey('meal_menus') ? MealData.fromJson(Map<String, dynamic>.from(data['meal_menus'])) : null;
      final projectUpdates = data.containsKey('project_updates')
          ? ProjectUpdatesData.fromJson(Map<String, dynamic>.from(data['project_updates']))
          : null;
      final academicPeers = data.containsKey('academic_peers')
          ? AcademicPeersData.fromJson(Map<String, dynamic>.from(data['academic_peers']))
          : null;
      final lastTime = data.containsKey('last_time')
          ? LastTimeData.fromJson(Map<String, dynamic>.from(data['last_time']))
          : null;
      final preferences = parseBackupPreferences(data['preferences']);
      final workLog = data.containsKey('work_log')
          ? WorkLogData.fromJson(Map<String, dynamic>.from(data['work_log']))
          : null;
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
      if (preferences != null) {
        final prefs = await SharedPreferences.getInstance();
        await restoreBackupPreferences(prefs, preferences);
        _loadPreferences(prefs);
      }
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
      if (data.containsKey('journal_entries')) {
        _recentlyDeleted.clear();
        await _persistJournal(entries);
      }
      if (data.containsKey('journal_collections')) {
        await _persistJournalCollections(journalCollections);
      }
      if (meals != null) await updateMeals((_) => meals);
      if (projectUpdates != null) await updateProjectUpdates((_) => projectUpdates);
      if (academicPeers != null) await updateAcademicPeers((_) => academicPeers);
      if (lastTime != null) await updateLastTime((_) => lastTime);
      if (workLog != null)
        await updateWorkLog((_) => workLog, rememberDeletions: false);
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

  void toggleCollectionFixed(String id) {
    final index = _collections.indexWhere((collection) => collection.id == id);
    if (index < 0) return;
    _collections[index].isFixed = !_collections[index].isFixed;
    _removeCompletedCollections();
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
    bool deadlineBlue = false,
    String? collectionId,
    List<String> tags = const [],
  }) {
    _normalTasks.add(
      TaskItem(
        id: const Uuid().v4(),
        title: title,
        type: TaskType.normal,
        deadline: deadline,
        deadlineBlue: deadlineBlue,
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
    bool? deadlineBlue,
    List<String>? newTags,
  }) {
    task.title = newTitle;
    task.deadline = newDeadline;
    if (deadlineBlue != null) task.deadlineBlue = deadlineBlue;
    if (newTags != null) {
      task.tags = newTags;
    }
    _saveData();
    notifyListeners();
  }

  void moveTask(TaskItem task, String? collectionId) {
    if (task.type != TaskType.normal || !_normalTasks.contains(task)) return;
    if (collectionId != null && !_collections.any((c) => c.id == collectionId))
      return;
    task.collectionId = collectionId;
    _removeCompletedCollections();
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
    _removeCompletedCollections();
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
  Set<String> _lastCalendarAlertIds = {};
  void _maintainData() {
    if (_disposed) return;
    final recoveredCount = _recentlyDeleted.length;
    _recentlyDeleted.removeWhere((_, item) => !_recoverable(item.deletedAt));
    final now = _now();
    clock.value = now;
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
    final countdownCount = _countdowns.length;
    _countdowns.removeWhere((task) => !task.deadline.isAfter(now));
    bool changed =
        before != _normalTasks.length || countdownCount != _countdowns.length;
    bool cyclesChanged = false;
    for (final task in _cycleTasks) {
      if (!task.nextRunTime.isAfter(now)) {
        task.nextRunTime = nextOccurrence(task.time, task.frequency, now);
        cyclesChanged = true;
      }
    }
    final collectionsChanged = _removeCompletedCollections();
    final dataChanged = changed || cyclesChanged || collectionsChanged;
    final alerts = calendarAlertIds;
    final alertsChanged = !setEquals(alerts, _lastCalendarAlertIds);
    _lastCalendarAlertIds = alerts;
    if (dataChanged) _saveData();
    if (dataChanged ||
        alertsChanged ||
        recoveredCount != _recentlyDeleted.length) {
      notifyListeners();
    } else if (_backupDay != workLogDateKey(now) &&
        !(_backupTimer?.isActive ?? false)) {
      // A new calendar day still needs its backup even without business edits.
      _syncBackup();
    }
  }

  // Remove completed groups without discarding their completed task history.
  bool _removeCompletedCollections() {
    final completed = _collections
        .where((collection) {
          final tasks = _normalTasks.where(
            (task) => task.collectionId == collection.id,
          );
          return !collection.isFixed &&
              tasks.isNotEmpty &&
              tasks.every((task) => task.isCompleted);
        })
        .map((collection) => collection.id)
        .toSet();
    if (completed.isEmpty) return false;
    for (final task in _normalTasks) {
      if (completed.contains(task.collectionId)) task.collectionId = null;
    }
    _collections.removeWhere((collection) => completed.contains(collection.id));
    _hiddenTodoCollections.removeAll(completed);
    return true;
  }

  void toggleTaskCompletion(TaskItem task) {
    task.isCompleted = !task.isCompleted;
    task.finishedAt = task.isCompleted ? DateTime.now() : null;
    _removeCompletedCollections();
    _saveData();
    notifyListeners();
  }
}
