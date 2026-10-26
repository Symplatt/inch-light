import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/utils/journal_markdown_import.dart';
import 'package:inch_light/widgets/journal_collection_strip.dart';
import 'package:inch_light/widgets/app_dialog.dart';

JournalEntry note(List<dynamic> document) => JournalEntry(
  id: 'check-3135',
  title: '检查',
  document: document,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<AppProvider> mount(
  WidgetTester t,
  Widget child, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = const Size(400, 850);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final provider = AppProvider();
  await t.runAsync(() => provider.ready);
  await t.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates:
            q.FlutterQuillLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await t.pumpAndSettle();
  return provider;
}

void main() {
  test(
    'Word dots preserve case and periods are appended outside inline code',
    () {
      expect(
        transformJournalText(
          'agents.md hello.world hello. next',
          JournalOperation.capitalize,
        ),
        'Agents.md Hello.world Hello. Next',
      );
      final output = transformJournalDocument([
        {'insert': 'agents.'},
        {
          'insert': 'md 一句',
          'attributes': {'italic': true},
        },
        {
          'insert': '话',
          'attributes': {'code': true},
        },
        {'insert': '\n'},
      ], JournalOperation.capitalize);
      expect(q.Document.fromJson(output).toPlainText(), 'Agents.md 一句话\n');
      final punctuated = transformJournalDocument(
        output,
        JournalOperation.removeLeadingPunctuation,
      );
      expect(q.Document.fromJson(punctuated).toPlainText(), 'Agents.md 一句话。\n');
      final period = punctuated.firstWhere(
        (op) => op['insert'].toString().contains('。'),
      );
      expect(period['attributes']?['code'], isNot(true));
      expect(
        transformJournalDocument(
          punctuated,
          JournalOperation.removeLeadingPunctuation,
        ),
        punctuated,
      );
    },
  );

  test(
    'Markdown code spacing respects punctuation, whitespace and split styles',
    () {
      final result = journalToMarkdown(
        note([
          {'insert': '一句'},
          {
            'insert': '话',
            'attributes': {'code': true},
          },
          {'insert': '以后，'},
          {
            'insert': 'a',
            'attributes': {'code': true},
          },
          {
            'insert': 'b',
            'attributes': {'code': true, 'bold': true},
          },
          {'insert': '。已有 '},
          {
            'insert': '空格',
            'attributes': {'code': true},
          },
          {'insert': ' 保留\n'},
        ]),
      );
      expect(result, contains('一句 `话` 以后，`ab`。已有 `空格` 保留'));
    },
  );

  test(
    'Quote and list coexist, toggle independently and survive paste/export',
    () {
      final c = JournalController(
        document: q.Document.fromJson([
          {'insert': '第一段'},
          {
            'insert': '\n',
            'attributes': {'blockquote': true},
          },
          {'insert': '第二段'},
          {
            'insert': '\n',
            'attributes': {'blockquote': true},
          },
        ]),
        selection: const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      c.formatText(0, 7, q.Attribute.ul);
      var ops = c.document.toDelta().toJson();
      final endings = ops.where((op) => op['attributes']?['list'] == 'bullet');
      expect(endings, isNotEmpty);
      expect(
        endings.every((op) => op['attributes']['blockquote'] == true),
        true,
      );
      expect(journalToMarkdown(note(ops)), contains('> - 第一段\n> - 第二段'));
      c.formatText(0, 7, q.Attribute.clone(q.Attribute.ul, null));
      expect(
        c.document.toDelta().toJson().any(
          (op) => op['attributes']?['blockquote'] == true,
        ),
        true,
      );
      final pasted = q.Document.fromDelta(
        journalMarkdownInsertion('> - 引用里的列表')!.delta,
      ).toDelta().toJson();
      expect(
        pasted.any(
          (op) =>
              op['attributes']?['list'] == 'bullet' &&
              op['attributes']?['blockquote'] == true,
        ),
        true,
      );
      c.dispose();
    },
  );

  test(
    'Backup restores settings and chain; old backups preserve preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'loose_tasks_first': false,
        'countdowns_first': false,
        'journal_collection_sort': 'name',
        'journal_entry_sort': 'name',
        'journal_operation_chain': ['normalizeSpaces', 'capitalize'],
      });
      final source = AppProvider();
      await source.ready;
      final backup = source.exportData();
      source.dispose();
      SharedPreferences.setMockInitialValues({});
      final target = AppProvider();
      await target.ready;
      expect(await target.importData(backup), true);
      expect(target.looseTasksFirst, false);
      expect(target.countdownsFirst, false);
      expect(target.journalEntrySort, JournalSort.name);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'journal_operation_chain',
        ),
        ['normalizeSpaces', 'capitalize'],
      );
      final old = jsonDecode(backup) as Map<String, dynamic>
        ..remove('preferences');
      expect(await target.importData(jsonEncode(old)), true);
      expect(target.countdownsFirst, false);
      final invalid = jsonDecode(backup) as Map<String, dynamic>;
      invalid['preferences']['countdowns_first'] = 'bad';
      expect(await target.importData(jsonEncode(invalid)), false);
      expect(target.countdownsFirst, false);
      target.dispose();
    },
  );

  test(
    'Calendar detects both first and additional newly urgent cards',
    () async {
      SharedPreferences.setMockInitialValues({});
      var time = DateTime(2026, 10, 26, 12);
      final p = AppProvider(now: () => time);
      await p.ready;
      expect(p.hasCalendarAlerts, false);
      p.addCountdown('第一项', time.add(const Duration(hours: 23)));
      p.addCountdown('第二项', time.add(const Duration(hours: 25)));
      expect(p.hasNewCalendarAlerts, true);
      await p.markCalendarAlertsSeen();
      expect(p.hasCalendarAlerts, true);
      expect(p.hasNewCalendarAlerts, false);
      time = time.add(const Duration(hours: 2));
      expect(p.hasNewCalendarAlerts, true);
      await p.markCalendarAlertsSeen();
      expect(p.hasNewCalendarAlerts, false);
      p.dispose();
    },
  );

  testWidgets('A fast long edge drag opens the collection list once', (
    t,
  ) async {
    var opened = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalCollectionStrip(
            onOpenCollections: () => opened++,
            children: [
              for (var i = 0; i < 8; i++)
                SizedBox(width: 100, height: 60, child: Text('$i')),
            ],
          ),
        ),
      ),
    );
    final point =
        t.getTopLeft(find.byType(JournalCollectionStrip)) +
        const Offset(20, 25);
    final gesture = await t.startGesture(point);
    await gesture.moveBy(const Offset(320, 0));
    await gesture.up();
    await t.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets(
    'Long press runs chain, export stays a sheet and taps reopen the keyboard',
    (t) async {
      final p = await mount(
        t,
        JournalEditorPage(
          entry: note([
            {'insert': 'hello agents.md 一句话\n'},
          ]),
        ),
        prefs: {
          'journal_operation_chain': ['capitalize'],
        },
      );
      await t.longPress(find.byTooltip('操作'));
      await t.pumpAndSettle();
      expect(find.text('已完成连携操作（长按魔法棒快捷执行）'), findsOneWidget);
      var editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
      expect(
        editor.controller.document.toPlainText(),
        startsWith('Hello Agents.md'),
      );
      expect(editor.focusNode.hasFocus, false);
      await t.tap(find.byTooltip('导出'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      Navigator.of(t.element(find.text('复制 Markdown'))).pop();
      await t.pumpAndSettle();
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.textInput, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(SystemChannels.textInput, null),
      );
      final at =
          t.getTopLeft(find.byType(q.QuillEditor)) + const Offset(60, 20);
      for (var i = 0; i < 2; i++) {
        await t.tapAt(at);
        await t.pumpAndSettle();
        editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
        expect(editor.focusNode.hasPrimaryFocus, true);
        expect(calls, contains('TextInput.show'));
        editor.focusNode.unfocus();
        await t.pumpAndSettle();
        calls.clear();
      }
      expect(t.takeException(), null);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets('Software info fits three buttons and opens shortcut guide', (
    t,
  ) async {
    final p = await mount(t, const SettingsPage());
    await t.tap(find.byTooltip('软件信息'));
    await t.pumpAndSettle();
    for (final text in ['快捷操作说明', '开源许可', '关闭']) {
      expect(find.text(text), findsOneWidget);
    }
    final buttons = [
      '快捷操作说明',
      '开源许可',
      '关闭',
    ].map((text) => t.getCenter(find.text(text))).toList();
    expect(buttons.map((offset) => offset.dy).toSet().length, 1);
    await t.tap(find.text('快捷操作说明'));
    await t.pumpAndSettle();
    expect(find.byType(AppAlertDialog), findsNWidgets(2));
    expect(find.textContaining('长按魔法棒'), findsOneWidget);
    expect(t.takeException(), null);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets(
    'Todo loose items and collections can swipe left; right hide remains',
    (t) async {
      final p = await mount(t, const TodoPage());
      p.addCollection('合集检查');
      p.addNormalTask('零散检查');
      await t.pumpAndSettle();
      await t.drag(find.text('零散检查'), const Offset(-350, 0));
      await t.pumpAndSettle();
      expect(p.normalTasks, isEmpty);
      await t.drag(find.text('合集检查'), const Offset(-350, 0));
      await t.pumpAndSettle();
      expect(p.collections, isEmpty);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
