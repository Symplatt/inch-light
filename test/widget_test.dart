import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/task_model.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/main_screen.dart';
import 'package:inch_light/utils/schedule.dart';
import 'package:inch_light/utils/deadline.dart';
import 'package:inch_light/constants/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Upgrade preserves task type IDs and removes retired stored data', () async {
    SharedPreferences.setMockInitialValues({
      'timer_tasks': '[]',
      'daily_tasks': jsonEncode([{'id': 'daily', 'title': '打卡', 'type': 1}]),
      'normal_tasks': jsonEncode([{'id': 'normal', 'title': '事项', 'type': 2}]),
    });
    final provider = AppProvider();
    await provider.ready;
    addTearDown(provider.dispose);
    expect(provider.dailyTasks.single.type, TaskType.daily);
    expect(provider.normalTasks.single.type, TaskType.normal);
    expect(provider.dailyTasks.single.toJson()['type'], 1);
    expect(provider.normalTasks.single.toJson()['type'], 2);
    expect((await SharedPreferences.getInstance()).containsKey('timer_tasks'), isFalse);
    expect(jsonDecode(provider.exportData()).containsKey('timer_tasks'), isFalse);
  });

  test(
    'Deadline urgency changes exactly at 24 hours and preserves overdue red',
    () {
      final now = DateTime(2026, 9, 28, 12);
      expect(
        deadlineColor(now.add(const Duration(hours: 24, seconds: 1)), now: now),
        AppColors.success,
      );
      expect(
        deadlineColor(now.add(const Duration(hours: 24)), now: now),
        const Color(0xFFC9A000),
      );
      expect(
        deadlineColor(now.add(const Duration(hours: 1)), now: now),
        const Color(0xFFC9A000),
      );
      expect(
        deadlineColor(now.subtract(const Duration(seconds: 1)), now: now),
        AppColors.danger,
      );
    },
  );

  test('Monthly recurrence restores anchor day after February', () {
    final anchor = DateTime(2024, 1, 31, 9);
    expect(
      nextOccurrence(anchor, CycleFrequency.monthly, DateTime(2024, 2, 1)),
      DateTime(2024, 2, 29, 9),
    );
    expect(
      nextOccurrence(anchor, CycleFrequency.monthly, DateTime(2024, 2, 29, 9)),
      DateTime(2024, 3, 31, 9),
    );
    expect(
      nextOccurrence(
        DateTime(2020, 2, 29, 8),
        CycleFrequency.yearly,
        DateTime(2023, 3),
      ),
      DateTime(2024, 2, 29, 8),
    );
    expect(
      nextOccurrence(
        DateTime(2024, 1, 1, 8),
        CycleFrequency.weekly,
        DateTime(2024, 1, 1, 8),
      ),
      DateTime(2024, 1, 8, 8),
    );
  });

  test(
    'Legacy import, extended round trip, atomic invalid import and cleanup',
    () async {
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      final oldTask = {
        'id': 'old',
        'title': '旧事项',
        'type': 2,
        'isPinned': true,
      };
      expect(
        await provider.importData(
          jsonEncode({
            'normal_tasks': [oldTask],
            'collections': [],
          }),
        ),
        isTrue,
      );
      expect(provider.normalTasks.single.isPinned, isTrue);
      expect(provider.normalTasks.single.isBottom, isFalse);
      final captured = DateTime(2026, 9, 28, 12, 1);
      provider.addJournalEntry('# 标题\n**正文**', captured);
      provider.addCountdown('纪念日', DateTime(2030));
      final exported = provider.exportData();
      expect(await provider.importData(exported), isTrue);
      expect(provider.journalEntries.single.createdAt, captured);
      expect(provider.countdowns.single.deadline, DateTime(2030));
      expect(
        await provider.importData('{"normal_tasks": [], "cycle_tasks": [42]}'),
        isFalse,
      );
      expect(provider.exportData(), exported);
      expect(await provider.importData('{}'), isFalse);
      expect(
        await provider.importData(
          jsonEncode({
            'normal_tasks': [
              {
                ...oldTask,
                'id': 'expired',
                'isCompleted': true,
                'finishedAt': DateTime.now()
                    .subtract(const Duration(hours: 25))
                    .toIso8601String(),
              },
              {
                ...oldTask,
                'id': 'recent',
                'isCompleted': true,
                'finishedAt': DateTime.now()
                    .subtract(const Duration(hours: 23))
                    .toIso8601String(),
              },
              {...oldTask, 'id': 'unfinished'},
            ],
          }),
        ),
        isTrue,
      );
      expect(provider.normalTasks.map((t) => t.id), ['recent', 'unfinished']);
      expect(provider.journalEntries.single.createdAt, captured);
    },
  );

  test(
    'Positions and collection bulk actions respect collection boundaries',
    () async {
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      provider.addCollection('合集');
      final id = provider.collections.single.id;
      provider.addNormalTask('早截止', deadline: DateTime(2030), collectionId: id);
      provider.addNormalTask('晚截止', deadline: DateTime(2031), collectionId: id);
      provider.addNormalTask('合集之外');
      provider.setTaskPosition(provider.normalTasks.first, 1);
      expect(
        provider.getTasksInCollection(id, isCompleted: false).first.title,
        '晚截止',
      );
      expect(provider.nearestDeadline(id), DateTime(2030));
      provider.completeCollection(id);
      expect(provider.normalTasks.last.isCompleted, isFalse);
      expect(provider.nearestDeadline(id), isNull);
      provider.clearCollectionTasks(id);
      expect(provider.normalTasks.single.title, '合集之外');
      expect(provider.collections.length, 1);
    },
  );

  testWidgets(
    'Todo is home, record captures opening time and Markdown renders',
    (tester) async {
      final provider = AppProvider();
      await tester.runAsync(() => provider.ready);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: MainScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('待办清单'), findsOneWidget);
      await tester.tap(find.text('记录').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final stamp = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:').hasMatch(t));
      await tester.enterText(
        find.byType(TextField),
        '# 一级\n## 二级\n### 三级\n**加粗**',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(provider.journalEntries.length, 1);
      expect(
        provider.journalEntries.single.createdAt
            .toIso8601String()
            .substring(0, 19)
            .replaceFirst('T', ' '),
        stamp,
      );
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
