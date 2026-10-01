import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/models/task_model.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/utils/countdown.dart';
import 'package:inch_light/utils/deadline.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Inline collection creation and rename retain contained items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.create_new_folder_outlined), findsNothing);
    expect(find.byTooltip('导入 / 导出数据'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('普通事项'), findsOneWidget);
    expect(find.text('每日打卡'), findsOneWidget);
    expect(find.text('新建事项'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(
      tester.getTopLeft(find.text('合集')).dy,
      tester.getTopLeft(find.text('普通事项')).dy,
    );
    expect(
      tester.getTopLeft(find.text('合集')).dx,
      greaterThan(tester.getTopLeft(find.text('每日打卡')).dx),
    );
    await tester.tap(find.text('合集'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('今日截止'), findsNothing);
    await tester.enterText(find.byType(TextField), '原名称');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final id = provider.collections.single.id;
    provider.addNormalTask('合集内事项', collectionId: id);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('原名称'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改合集名称'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '原名称',
    );
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(provider.collections.single.title, '原名称');
    await tester.enterText(find.byType(TextField), ' 新名称 ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(provider.collections.single.id, id);
    expect(provider.collections.single.title, '新名称');
    expect(provider.normalTasks.single.collectionId, id);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final restored = AppProvider();
      await restored.ready;
      expect(restored.collections.single.title, '新名称');
      restored.dispose();
    });
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('普通事项'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  test('All-day countdown round trip and legacy default', () async {
    final provider = AppProvider();
    await provider.ready;
    provider.addCountdown('全天', DateTime(2030, 1, 1), allDay: true);
    final backup = provider.exportData();
    expect(await provider.importData(backup), isTrue);
    expect(provider.countdowns.single.allDay, isTrue);
    expect(
      CalendarCountdown.fromJson({
        'id': 'old',
        'title': '旧数据',
        'deadline': '2030-01-01T12:00:00.000',
      }).allDay,
      isFalse,
    );
    provider.dispose();
  });
  test('Tomorrow deadline crosses month and year boundaries', () {
    expect(
      endOfDay(1, now: DateTime(2026, 12, 31)),
      DateTime(2027, 1, 1, 23, 59),
    );
    expect(
      endOfDay(1, now: DateTime(2028, 2, 28)),
      DateTime(2028, 2, 29, 23, 59),
    );
  });

  testWidgets(
    'Calendar edits persist with stable IDs and swipes delete both ways',
    (tester) async {
      final provider = AppProvider();
      await tester.runAsync(() => provider.ready);
      provider.addCountdown('旅行', DateTime.now().add(const Duration(days: 60)));
      provider.addCycleTask(
        '整理',
        CycleFrequency.monthly,
        DateTime.now().add(const Duration(days: 5)),
      );
      final countdownId = provider.countdowns.single.id;
      final cycleId = provider.cycleTasks.single.id;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: provider, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('时历').last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.longPress(find.text('旅行'));
      await tester.pumpAndSettle();
      expect(find.text('编辑事项'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '旅行改期');
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(provider.countdowns.single.id, countdownId);
      expect(provider.countdowns.single.title, '旅行改期');
      expect(provider.countdowns.single.allDay, isTrue);
      expect(provider.countdowns.single.deadline.hour, 0);
      expect(find.textContaining('· 全天'), findsWidgets);
      await tester.longPress(find.text('整理'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '每月收纳');
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(provider.cycleTasks.single.id, cycleId);
      expect(provider.cycleTasks.single.allDay, isTrue);
      expect(provider.cycleTasks.single.time.hour, 0);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final restored = AppProvider();
        await restored.ready;
        expect(restored.countdowns.single.title, '旅行改期');
        expect(restored.countdowns.single.allDay, isTrue);
        expect(restored.cycleTasks.single.title, '每月收纳');
        expect(restored.cycleTasks.single.allDay, isTrue);
        restored.dispose();
      });
      await tester.drag(find.text('旅行改期'), const Offset(800, 0));
      await tester.pumpAndSettle();
      expect(provider.countdowns, isEmpty);
      await tester.drag(find.text('每月收纳'), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(provider.cycleTasks, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );

  test('Countdown respects 24 hours, month ends, leap years and expiry', () {
    final now = DateTime(2024, 1, 31, 12);
    expect(countdownParts(now, now), isEmpty);
    expect(
      countdownParts(now.subtract(const Duration(seconds: 1)), now),
      isEmpty,
    );
    expect(countdownParts(now.add(const Duration(hours: 24)), now), [
      (value: 0, unit: '年'),
      (value: 0, unit: '月'),
      (value: 1, unit: '日'),
    ]);
    expect(
      countdownParts(
        now.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
        now,
      ),
      [(value: 23, unit: '时'), (value: 59, unit: '分'), (value: 59, unit: '秒')],
    );
    expect(countdownParts(DateTime(2024, 2, 29, 12), now), [
      (value: 0, unit: '年'),
      (value: 1, unit: '月'),
      (value: 0, unit: '日'),
    ]);
    expect(
      countdownParts(DateTime(2025, 2, 28, 12), DateTime(2024, 2, 29, 12)),
      [(value: 1, unit: '年'), (value: 0, unit: '月'), (value: 0, unit: '日')],
    );
    expect(countdownParts(DateTime(2025, 4, 2, 11), now), [
      (value: 1, unit: '年'),
      (value: 2, unit: '月'),
      (value: 1, unit: '日'),
    ]);
  });

  for (final completed in [false, true]) {
    testWidgets(
      'Deleting collection from completed=$completed removes both states',
      (tester) async {
        final provider = AppProvider();
        await tester.runAsync(() => provider.ready);
        provider.addCollection('完整合集');
        final id = provider.collections.single.id;
        provider.addNormalTask('未完成项目', collectionId: id);
        provider.addNormalTask('已完成项目', collectionId: id);
        provider.toggleTaskCompletion(provider.normalTasks.last);
        provider.addNormalTask('合集之外');
        await tester.pumpWidget(
          ChangeNotifierProvider.value(value: provider, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        if (completed) {
          await tester.tap(find.byTooltip('查看已完成'));
          await tester.pumpAndSettle();
        }
        await tester.drag(find.text('完整合集'), const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(provider.collections, isEmpty);
        expect(provider.normalTasks.single.title, '合集之外');
        provider.addCollection('另一合集');
        provider.addNormalTask(
          '另一个项目',
          collectionId: provider.collections.single.id,
        );
        provider.clearCollections();
        expect(provider.normalTasks.single.title, '合集之外');
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      },
    );
  }

  testWidgets('Today deadline works directly in create and edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '今天完成');
    await tester.tap(find.text('今日截止'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final expected = DateTime(now.year, now.month, now.day, 23, 59);
    expect(provider.normalTasks.single.deadline, expected);
    provider.normalTasks.single.deadline = now.add(const Duration(days: 5));
    await tester.longPress(find.text('今天完成'));
    await tester.pumpAndSettle();
    expect(find.text('编辑事项'), findsOneWidget);
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(provider.normalTasks.single.isPinned, isTrue);
    await tester.tap(find.text('置底'));
    await tester.pumpAndSettle();
    expect(provider.normalTasks.single.isPinned, isFalse);
    expect(provider.normalTasks.single.isBottom, isTrue);
    expect(
      tester.getTopLeft(find.text('今日截止')).dx,
      lessThan(tester.getTopLeft(find.text('明日截止')).dx),
    );
    await tester.tap(find.text('明日截止'));
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(
      provider.normalTasks.single.deadline,
      DateTime(now.year, now.month, now.day + 1, 23, 59),
    );
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('Calendar sections fold independently and fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    provider.addCountdown('下次旅行', DateTime.now().add(const Duration(days: 60)));
    provider.addCountdown('今晚提交', DateTime.now().add(const Duration(hours: 2)));
    provider.addCycleTask(
      '每月整理',
      CycleFrequency.monthly,
      DateTime.now().add(const Duration(days: 5)),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('时历').last);
    await tester.pumpAndSettle();
    expect(find.text('年'), findsWidgets);
    expect(find.text('秒'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('section-倒计时')));
    await tester.pumpAndSettle();
    expect(find.text('下次旅行'), findsNothing);
    expect(find.text('每月整理'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('section-周期')));
    await tester.pumpAndSettle();
    expect(find.text('每月整理'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('section-倒计时')));
    await tester.pumpAndSettle();
    expect(find.text('下次旅行'), findsOneWidget);
    expect(find.text('每月整理'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
