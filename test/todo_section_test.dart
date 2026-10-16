import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/providers/app_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Only collection and loose section bulk buttons are removed', (
    tester,
  ) async {
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    provider.addCollection('保留合集');
    provider.addNormalTask('零散');
    provider.addDailyTask('日常');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    for (final completed in [false, true]) {
      if (completed) {
        await tester.tap(find.byTooltip('查看已完成'));
        await tester.pumpAndSettle();
      } else {
        expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
      }
      for (final title in ['事项合集', '零散事项']) {
        final header = find
            .ancestor(of: find.text(title), matching: find.byType(Row))
            .first;
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.byType(IconButton)),
          findsNothing,
        );
      }
    }
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('导出备份'), findsOneWidget);
    expect(find.text('粘贴导入'), findsOneWidget);
    expect(find.text('事项顺序'), findsOneWidget);
    for (final label in ['本地备份', '每日自动备份', '读取本地备份']) {
      expect(find.text(label), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  test(
    'Withdrawn backup cache is removed while live data is retained',
    () async {
      final tasks = jsonEncode([
        {'id': 'live-task', 'title': '保留事项', 'type': 2},
      ]);
      SharedPreferences.setMockInitialValues({
        'normal_tasks': tasks,
        'local_backup_snapshot': '{"normal_tasks":[]}',
        'loose_tasks_first': false,
      });
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('local_backup_snapshot'), isFalse);
      expect(prefs.getString('normal_tasks'), tasks);
      expect(provider.normalTasks.single.id, 'live-task');
      expect(provider.looseTasksFirst, isFalse);
    },
  );
}
