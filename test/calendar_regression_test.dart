import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/models/task_model.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/utils/countdown.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    await tester.tap(find.text('编辑事项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日截止'));
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(provider.normalTasks.single.deadline, expected);
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
