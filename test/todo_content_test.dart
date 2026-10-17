import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/providers/app_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Task type selection keeps chip widths and horizontal positions fixed',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = AppProvider();
      await tester.runAsync(() => provider.ready);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: provider, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      const labels = ['普通事项', '每日打卡', '合集'];
      List<Rect> rects() => labels
          .map(
            (label) => tester.getRect(find.widgetWithText(ChoiceChip, label)),
          )
          .toList();
      final before = rects();
      for (final label in ['每日打卡', '合集', '普通事项', '每日打卡']) {
        await tester.tap(find.widgetWithText(ChoiceChip, label));
        for (final duration in [
          Duration.zero,
          const Duration(milliseconds: 16),
          const Duration(milliseconds: 80),
          const Duration(milliseconds: 200),
        ]) {
          await tester.pump(duration);
          final after = rects();
          for (var index = 0; index < before.length; index++) {
            expect(after[index].left, before[index].left);
            expect(after[index].width, before[index].width);
            expect(after[index].height, before[index].height);
          }
        }
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
              .selected,
          true,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );

  testWidgets('Loose tasks precede collections in both completion views', (
    tester,
  ) async {
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    provider.addDailyTask('日常');
    provider.addNormalTask('零散待办');
    provider.addNormalTask('零散完成');
    provider.toggleTaskCompletion(provider.normalTasks.last);
    provider.addCollection('测试合集');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    for (final completed in [false, true]) {
      if (completed) {
        await tester.tap(find.byTooltip('查看已完成'));
        await tester.pumpAndSettle();
      } else {
        expect(
          tester.getTopLeft(find.text('日常打卡')).dy,
          lessThan(tester.getTopLeft(find.text('零散事项')).dy),
        );
      }
      expect(
        tester.getTopLeft(find.text('零散事项')).dy,
        lessThan(tester.getTopLeft(find.text('事项合集')).dy),
      );
      expect(find.text(completed ? '零散完成' : '零散待办'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  for (final kind in ['normal', 'daily', 'collection']) {
    testWidgets('Multiline $kind content survives create, edit and backup', (
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
      if (kind == 'collection') provider.addCollection('多行合集');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: provider, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      if (kind == 'collection') {
        await tester.tap(
          find.descendant(
            of: find.byType(ExpansionTile),
            matching: find.byType(IconButton),
          ),
        );
      } else {
        await tester.tap(find.byType(FloatingActionButton));
      }
      await tester.pumpAndSettle();
      if (kind == 'daily') {
        await tester.tap(find.text('每日打卡'));
        await tester.pumpAndSettle();
      }
      final content = find.byType(TextField).first;
      await tester.enterText(content, '第一行');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(find.text('完成'), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      const created = '第一行\n第二行';
      await tester.enterText(content, created);
      await tester.ensureVisible(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      final task = kind == 'daily'
          ? provider.dailyTasks.single
          : provider.normalTasks.single;
      final id = task.id;
      expect(task.title, created);
      if (kind == 'collection') {
        expect(task.collectionId, provider.collections.single.id);
      }
      await tester.longPress(find.text(created));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        created,
      );
      const edited = '第一行\n第二行\n第三行\n第四行\n第五行\n第六行\n第七行\n第八行';
      await tester.enterText(find.byType(TextField).first, edited);
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.ensureVisible(find.text('保存修改'));
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(task.id, id);
      expect(task.title, edited);
      final backup = provider.exportData();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final restored = AppProvider();
        await restored.ready;
        final stored = kind == 'daily'
            ? restored.dailyTasks.single
            : restored.normalTasks.single;
        expect(stored.id, id);
        expect(stored.title, edited);
        expect(await restored.importData(backup), isTrue);
        final imported = kind == 'daily'
            ? restored.dailyTasks.single
            : restored.normalTasks.single;
        expect(imported.title, edited);
        expect(imported.collectionId, task.collectionId);
        restored.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }
}
