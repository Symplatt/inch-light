import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final file in [true, false]) {
    testWidgets(
      '${file ? 'File' : 'Clipboard'} plain JSON import opens confirmation dialog and restores data',
      (t) async {
        t.view.physicalSize = const Size(400, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final source = AppProvider();
        await t.runAsync(() => source.ready);
        source.addNormalTask('待恢复事项');
        final payload = source.exportData();
        final p = AppProvider();
        await t.runAsync(() => p.ready);
        p.addNormalTask('旧事项');
        const channel = MethodChannel('inch_light/data_export');
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'importFile' ? payload : null,
        );
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': payload} : null,
        );
        addTearDown(() {
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: p,
            child: const MaterialApp(home: SettingsPage()),
          ),
        );
        await t.pumpAndSettle();
        final action = find.text(file ? '文件导入' : '粘贴导入');
        await t.ensureVisible(action);
        await t.tap(action);
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('确认导入').hitTestable(), findsOneWidget);
        await t.tap(find.text('确认导入'));
        await t.pumpAndSettle();
        expect(find.text('导入成功'), findsOneWidget);
        expect(p.normalTasks.single.title, '待恢复事项');
        await t.pumpWidget(const SizedBox());
        p.dispose();
        source.dispose();
      },
    );
  }
  final fixture = Platform.environment['INCH_LIGHT_IMPORT_FIXTURE'];
  if (fixture != null) {
    test(
      'Provided complete backup imports every section and survives restart',
      () async {
        final saved = File(fixture).readAsStringSync();
        final text = saved.substring(
          saved.indexOf('{'),
          saved.lastIndexOf('}') + 1,
        );
        final data = jsonDecode(text) as Map;
        // Evaluate the snapshot at file creation time, before ordinary timed
        // retention can expire history while this regression is running.
        final snapshotTime = File(fixture).lastModifiedSync();
        final p = AppProvider(now: () => snapshotTime);
        await p.ready;
        expect(await p.importData(text), true);
        final actual = jsonDecode(p.exportData()) as Map;
        for (final key in data.keys) {
          expect(actual[key], data[key], reason: key);
        }
        p.dispose();
        final restored = AppProvider(now: () => snapshotTime);
        await restored.ready;
        expect(jsonDecode(restored.exportData()), actual);
        restored.dispose();
      },
    );
  }
}
