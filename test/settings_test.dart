import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/providers/app_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings order applies to both views and survives restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    provider.addNormalTask('零散');
    provider.addCollection('合集');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.import_export_rounded), findsNothing);
    await tester.tap(find.text('时历').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.import_export_rounded), findsNothing);
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('从剪贴板导入'), findsOneWidget);
    for (final looseFirst in [false, true]) {
      await tester.tap(find.text(looseFirst ? '零散事项在上' : '事项合集在上'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final restored = AppProvider();
        await restored.ready;
        expect(restored.looseTasksFirst, looseFirst);
        restored.dispose();
      });
      await tester.tap(find.text('待办').last);
      await tester.pumpAndSettle();
      for (final completed in [false, true]) {
        if (completed) {
          await tester.tap(find.byTooltip('查看已完成'));
          await tester.pumpAndSettle();
        }
        final upper = looseFirst ? '零散事项' : '事项合集';
        final lower = looseFirst ? '事项合集' : '零散事项';
        expect(
          tester.getTopLeft(find.text(upper)).dy,
          lessThan(tester.getTopLeft(find.text(lower)).dy),
        );
      }
      await tester.tap(find.byTooltip('查看待办'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('Settings exports clipboard data and confirms imports', (
    tester,
  ) async {
    String? clipboard;
    String? fileData;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      if (call.method == 'Clipboard.getData') {
        return clipboard == null ? null : {'text': clipboard};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('inch_light/data_export'),
      (call) async {
        fileData = call.arguments['data'] as String;
        return '/storage/emulated/0/inch-light/inch-light-2026-10-13_12-00-00_001.json';
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('inch_light/data_export'),
        null,
      ),
    );
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    provider.addNormalTask('原事项\n内容');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('导出数据'));
    await tester.tap(find.text('导出数据'));
    await tester.pumpAndSettle();
    expect(clipboard, provider.exportData());
    expect(fileData, clipboard);
    expect(
      find.textContaining('已复制并保存到 /storage/emulated/0/inch-light/'),
      findsOneWidget,
    );
    clipboard = jsonEncode({
      'normal_tasks': [
        {'id': 'imported', 'title': '备份\n事项', 'type': 2},
      ],
    });
    await tester.ensureVisible(find.text('从剪贴板导入'));
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(provider.normalTasks.single.title, '原事项\n内容');
    await tester.ensureVisible(find.text('从剪贴板导入'));
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认导入'));
    await tester.pumpAndSettle();
    expect(provider.normalTasks.single.id, 'imported');
    expect(provider.normalTasks.single.title, '备份\n事项');
    expect(find.text('导入成功'), findsOneWidget);
    clipboard = '{"normal_tasks":[42]}';
    await tester.ensureVisible(find.text('从剪贴板导入'));
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认导入'));
    await tester.pumpAndSettle();
    expect(provider.normalTasks.single.id, 'imported');
    expect(find.text('数据格式错误'), findsOneWidget);
    clipboard = '  ';
    await tester.ensureVisible(find.text('从剪贴板导入'));
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    expect(find.text('剪贴板为空'), findsOneWidget);
    expect(find.text('确认覆盖？'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  test(
    'Seven-day cleanup retains recent, unfinished and undated tasks',
    () async {
      final now = DateTime.now();
      Map<String, dynamic> task(
        String id,
        Duration age, {
        bool completed = true,
        String? collectionId,
      }) => {
        'id': id,
        'title': id,
        'type': 2,
        'isCompleted': completed,
        'finishedAt': now.subtract(age).toIso8601String(),
        'collectionId': collectionId,
      };
      SharedPreferences.setMockInitialValues({
        'normal_tasks': jsonEncode([
          task('recent', const Duration(days: 1)),
          task('almost-seven', const Duration(days: 6, hours: 23, minutes: 59)),
          task('seven-days', const Duration(days: 7)),
          task(
            'old-collection',
            const Duration(days: 8),
            collectionId: 'collection',
          ),
          task('unfinished', const Duration(days: 8), completed: false),
          {'id': 'undated', 'title': 'undated', 'type': 2, 'isCompleted': true},
        ]),
      });
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      final retained = ['recent', 'almost-seven', 'unfinished', 'undated'];
      expect(provider.normalTasks.map((t) => t.id), retained);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final restored = AppProvider();
      await restored.ready;
      addTearDown(restored.dispose);
      expect(restored.normalTasks.map((t) => t.id), retained);
    },
  );
}
