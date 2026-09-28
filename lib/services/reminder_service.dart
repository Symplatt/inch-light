import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task_model.dart';
import '../utils/schedule.dart';

class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  DateTime? scheduledThrough;
  bool precise = true;

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    if (!supported) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> requestPermission() async {
    if (!supported) return;
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null &&
        await android.canScheduleExactNotifications() == false) {
      await android.requestExactAlarmsPermission();
    }
  }

  Future<void> sync(
    List<CycleTask> cycles,
    List<CalendarCountdown> countdowns,
  ) {
    final result = _queue.then((_) => _sync(cycles, countdowns));
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _sync(
    List<CycleTask> cycles,
    List<CalendarCountdown> countdowns,
  ) async {
    if (!supported) return;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    precise = await android?.canScheduleExactNotifications() ?? true;
    final now = DateTime.now();
    // Reserve slots below iOS's 64-notification limit; Android has a larger queue.
    final limit = defaultTargetPlatform == TargetPlatform.iOS ? 60 : 450;
    final events = <({String title, DateTime time})>[
      for (final task in countdowns)
        if (task.deadline.isAfter(now))
          (title: task.title, time: task.deadline),
    ];
    for (final task in cycles) {
      var cursor = now;
      for (var i = 0; i < limit; i++) {
        cursor = nextOccurrence(task.time, task.frequency, cursor);
        events.add((title: task.title, time: cursor));
      }
    }
    events.sort((a, b) => a.time.compareTo(b.time));
    final selected = events.take(limit).toList();
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (pending.id >= 10000 && pending.id < 10450) {
        await _plugin.cancel(pending.id);
      }
    }
    scheduledThrough = null;
    for (var i = 0; i < selected.length; i++) {
      final event = selected[i];
      if (!event.time.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        10000 + i,
        '一日千录',
        event.title,
        tz.TZDateTime.from(event.time.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'calendar_reminders',
            '时历提醒',
            channelDescription: '重要日期与长倒计时提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: precise
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledThrough = event.time;
    }
    final enabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    if (selected.isNotEmpty && enabled == false) {
      throw StateError('Notifications disabled');
    }
    final iosPermissions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    if (selected.isNotEmpty && iosPermissions?.isEnabled == false) {
      throw StateError('Notifications disabled');
    }
  }
}
