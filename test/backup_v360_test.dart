import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/cycle_page.dart';
import 'package:inch_light/widgets/swipe_delete_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Calendar ignores right swipe and still deletes on left swipe', (
    t,
  ) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    p.addCountdown('方向验证', DateTime(2099));
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: CyclePage()),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(find.byType(SwipeDeleteCard), const Offset(600, 0));
    await t.pumpAndSettle();
    expect(p.countdowns, hasLength(1));
    await t.drag(find.byType(SwipeDeleteCard), const Offset(-600, 0));
    await t.pumpAndSettle();
    expect(p.countdowns, isEmpty);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets(
    'Backup publishes complete export and retries failed synchronization',
    (t) async {
      const channel = MethodChannel('inch_light/data_export');
      final snapshots = <String>[];
      var fail = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'syncBackup') {
              if (fail) throw PlatformException(code: 'storage');
              snapshots.add((call.arguments as Map)['data'] as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      await t.pump();
      fail = false;
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      p.addNormalTask('完整备份');
      await t.pump();
      expect(jsonDecode(snapshots.last), jsonDecode(p.exportData()));
      expect(
        (jsonDecode(snapshots.last) as Map).keys,
        containsAll([
          'journal_entries',
          'journal_collections',
          'calendar_countdowns',
          'daily_tasks',
          'normal_tasks',
          'cycle_tasks',
          'collections',
        ]),
      );
      final count = snapshots.length;
      await t.pump(const Duration(seconds: 2));
      expect(snapshots.length, count);
      p.dispose();
    },
  );
}
