import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/widgets/swipe_delete_card.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/utils/journal_table_markdown.dart';
import 'package:inch_light/utils/clipboard.dart';
import 'package:inch_light/widgets/journal_table.dart';
import 'package:inch_light/constants/app_colors.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Pasted Markdown tables preserve escaped cells, get fresh IDs, and keep surrounding prose',
    () {
      var source = JournalTableData.empty(2, 2);
      source = source
          .edit(source.rows[0].id, 0, '课次')
          .edit(source.rows[0].id, 1, '时间')
          .edit(source.rows[1].id, 0, r'一 | \ * <br>')
          .edit(source.rows[1].id, 1, '8:00 ~ 8:45\n下一行');
      final markdown = journalTableToMarkdown(source);
      final decoded = markdownTableBlocks(markdown).single.table;
      expect(decoded.rows.map((r) => r.cells), source.rows.map((r) => r.cells));
      expect(decoded.id, isNot(source.id));
      expect(markdownTableBlocks('```md\n$markdown\n```'), isEmpty);
      expect(markdownTableBlocks('| A | B |\n| -- | -- |'), isEmpty);
      final c = JournalController(
        document: quill.Document()..insert(0, '前后'),
        selection: const TextSelection.collapsed(offset: 1),
      );
      c.replaceText(1, 0, markdown, null);
      final ops = c.document.toDelta().toJson();
      expect(ops.where((o) => o['insert'] is Map), hasLength(1));
      expect(c.document.toPlainText(), '前\n\uFFFC\n后\n');
      final end = c.document.length - 1;
      c.replaceText(end, 0, markdown, null);
      final tables = c.document
          .toDelta()
          .toJson()
          .where((o) => o['insert'] is Map)
          .map((o) => JournalTableData.decode(o['insert']['table'] as String))
          .toList();
      expect(tables, hasLength(2));
      expect(tables.map((t) => t.id).toSet(), hasLength(2));
      c.dispose();
    },
  );

  test(
    'Columns borrow spare space to minimum width; twelve-column table grows only after five characters',
    () {
      var table = JournalTableData.empty(2, 2);
      table = table.edit(table.rows[0].id, 0, '汉' * 40);
      final widths = journalTableWidths(table, 360, TextScaler.noScaling);
      expect(widths[1], closeTo(34.5, .01));
      expect(widths[0], closeTo(325.5, .01));
      table = JournalTableData.empty(2, 12);
      var last = 108.5;
      for (var length = 1; length <= 12; length++) {
        table = table.edit(table.rows[0].id, 0, '汉' * length);
        final widths = journalTableWidths(table, 360, TextScaler.noScaling);
        if (length <= 5) expect(widths[0], 108.5);
        if (length > 5 && length <= 10) expect(widths[0], greaterThan(last));
        expect(widths[0], lessThanOrEqualTo(201));
        expect(widths.skip(1), everyElement(108.5));
        last = widths[0];
      }
    },
  );

  testWidgets(
    'One copy call retries a dropped platform write and verifies the new clipboard',
    (t) async {
      var writes = 0;
      var clipboard = '旧内容';
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData' && ++writes > 1) {
          clipboard = call.arguments['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await copyText('新表格');
      expect(writes, 2);
      expect(clipboard, '新表格');
    },
  );

  testWidgets(
    'Selection back exits selection; collection list shows counts and navigates',
    (t) async {
      late AppProvider p;
      await t.runAsync(() async {
        p = AppProvider();
        await p.ready;
        await p.addJournalCollection('大学');
        await p.saveJournalEntry(
          JournalEntry(
            id: 'n',
            title: '笔记',
            document: [
              {'insert': '正文\n'},
            ],
            createdAt: DateTime(2030),
            updatedAt: DateTime(2030),
          ),
        );
      });
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(home: JournalPage()),
        ),
      );
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(const ValueKey('note-card-n')),
        const Offset(130, 0),
      );
      await t.pumpAndSettle();
      expect(find.text('批量移动'), findsOneWidget);
      expect(
        t
            .widget<FloatingActionButton>(
              find.widgetWithText(FloatingActionButton, '全部删除'),
            )
            .backgroundColor,
        AppColors.danger,
      );
      await t.runAsync(() => t.binding.handlePopRoute());
      await t.pumpAndSettle();
      expect(find.text('批量移动'), findsNothing);
      expect(find.byTooltip('新建记录'), findsOneWidget);
      await t.tap(find.byTooltip('查看合集列表'));
      await t.pumpAndSettle();
      expect(find.text('合集 · 2'), findsOneWidget);
      expect(find.widgetWithText(ListTile, '默认'), findsOneWidget);
      await t.tap(find.widgetWithText(ListTile, '大学'));
      await t.pumpAndSettle();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(p.lastJournalCollection, p.journalCollections.single.id);
      expect(find.text('暂无记录'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'File import is directly on settings with inline confirmation and cancellation',
    (t) async {
      t.view.physicalSize = const Size(400, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      p.addNormalTask('原数据');
      const channel = MethodChannel('inch_light/data_export');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'importFile');
        return '{"normal_tasks":[]}';
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('从文件导入'));
      await t.tap(find.text('从文件导入'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(p.normalTasks, hasLength(1));
      await t.ensureVisible(find.text('取消'));
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(p.normalTasks.single.title, '原数据');
      await t.ensureVisible(find.text('从文件导入'));
      await t.tap(find.text('从文件导入'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('确认导入'));
      await t.tap(find.text('确认导入'));
      await t.pumpAndSettle();
      expect(p.normalTasks, isEmpty);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Todo and journal have identical drag, rebound and exit trajectories',
    (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final traces = <List<double>>[];
      for (final journal in [false, true]) {
        final p = AppProvider();
        await t.runAsync(() => p.ready);
        await t.pump();
        if (journal) {
          await t.runAsync(
            () => p.saveJournalEntry(
              JournalEntry(
                id: 'swipe',
                title: '测试',
                document: [
                  {'insert': '正文\n'},
                ],
                createdAt: DateTime(2030),
                updatedAt: DateTime(2030),
              ),
            ),
          );
        } else {
          p.addNormalTask('测试');
        }
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: p,
            child: MaterialApp(
              home: journal ? const JournalPage() : const TodoPage(),
            ),
          ),
        );
        await t.pumpAndSettle();
        final dismiss = find.byType(Dismissible).first;
        final slide = find
            .descendant(of: dismiss, matching: find.byType(SlideTransition))
            .first;
        final samples = <double>[];
        void sample() =>
            samples.add(t.widget<SlideTransition>(slide).position.value.dx);
        var gesture = await t.startGesture(t.getCenter(dismiss));
        await gesture.moveBy(const Offset(-20, 0));
        for (final dx in [-24.0, -36.0, 12.0]) {
          await gesture.moveBy(Offset(dx, 0));
          await t.pump(const Duration(milliseconds: 16));
          sample();
        }
        await gesture.up();
        await t.pump();
        await t.pump(const Duration(milliseconds: 70));
        sample();
        await t.pumpAndSettle();
        sample();
        expect(samples.last, 0);
        gesture = await t.startGesture(t.getCenter(dismiss));
        await gesture.moveBy(const Offset(-20, 0));
        await gesture.moveBy(const Offset(-210, 0));
        await t.pump();
        sample();
        await gesture.up();
        await t.pump();
        await t.pump(const Duration(milliseconds: 70));
        sample();
        expect(journal ? p.journalEntries.length : p.normalTasks.length, 1);
        await t.pumpAndSettle();
        expect(journal ? p.journalEntries : p.normalTasks, isEmpty);
        traces.add(samples);
        await t.pumpWidget(const SizedBox());
        p.dispose();
      }
      expect(traces[0], orderedEquals(traces[1]));
    },
  );

  testWidgets(
    'Failed asynchronous deletion restores a card for another swipe',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeleteCard(
              id: 'failed',
              onDeleted: () async {
                calls++;
                throw StateError('disk');
              },
              child: const SizedBox(width: 360, height: 90),
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await t.drag(find.byType(Dismissible), const Offset(-300, 0));
        await t.pumpAndSettle();
        expect(find.byType(Dismissible), findsOneWidget);
        expect(t.takeException(), isNull);
      }
      expect(calls, 2);
    },
  );
}
