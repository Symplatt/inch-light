import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_shortcuts.dart';
import 'package:inch_light/utils/journal_markdown.dart';

JournalEntry entry(String id, {List<dynamic>? document}) => JournalEntry(
  id: id,
  title: id,
  document:
      document ??
      [
        {'insert': '$id正文\n'},
      ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester t, AppProvider p, Widget page) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(home: page),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'Right swipe shifts every note equally, multi-move preserves content and multi-delete confirms',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final setup = () async {
        await p.addJournalCollection('目的合集');
        await p.saveJournalEntry(entry('甲'));
        await p.saveJournalEntry(entry('乙'));
        await p.saveJournalEntry(entry('丙'));
      }();
      await t.pumpAndSettle();
      await setup;
      await mount(t, p, const JournalPage());
      Finder card(String id) => find.byKey(ValueKey('note-card-$id'));
      final before = [
        for (final id in ['甲', '乙', '丙']) t.getTopLeft(card(id)).dx,
      ];
      await t.drag(card('甲'), const Offset(160, 0));
      await t.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(t.getTopLeft(card(['甲', '乙', '丙'][i])).dx - before[i], 44);
      }
      expect(find.byTooltip('全选'), findsOneWidget);
      expect(find.byTooltip('新建记录'), findsNothing);
      expect(find.byTooltip('新建合集'), findsNothing);
      await t.tap(card('甲'));
      await t.tap(card('乙'));
      await t.pump();
      await t.tap(find.text('批量移动'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(SimpleDialogOption, '目的合集'));
      await t.pumpAndSettle();
      expect(
        p.journalEntries
            .where((e) => e.collectionId != null)
            .map((e) => e.title)
            .toSet(),
        {'甲', '乙'},
      );
      expect(p.journalEntries.firstWhere((e) => e.id == '甲').content, '甲正文');
      await t.tap(find.text('目的合集'));
      await t.pumpAndSettle();
      await t.drag(card('甲'), const Offset(150, 0));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('全选'));
      await t.pump();
      await t.tap(find.text('全部删除'));
      await t.pumpAndSettle();
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(p.journalEntries, hasLength(3));
      await t.tap(find.text('全部删除'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, '删除'));
      await t.pumpAndSettle();
      expect(p.journalEntries.single.id, '丙');
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  testWidgets(
    'Whole table can be removed from its own menu, cancelled and undone',
    (t) async {
      final table = JournalTableData.empty(3, 2);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      await mount(
        t,
        p,
        JournalEditorPage(
          entry: entry(
            '表格',
            document: [
              {'insert': '前文\n'},
              {
                'insert': {'table': table.encode()},
              },
              {'insert': '\n后文\n'},
            ],
          ),
        ),
      );
      final c = t
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      final original = c.document.toDelta().toJson();
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': copied};
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      expect(find.byTooltip('表格操作'), findsNothing);
      final tableBounds = t.getRect(find.byType(Table));
      await t.tap(find.byKey(ValueKey('table-cell-${table.rows.first.id}-0')));
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(Table)), tableBounds);
      await t.tap(find.byTooltip('表格操作'));
      await t.pumpAndSettle();
      await t.tap(find.text('复制表格'));
      await t.pumpAndSettle();
      expect(copied, journalTableToMarkdown(table));
      expect(c.document.toDelta().toJson(), original);
      await t.tap(find.byKey(ValueKey('table-cell-${table.rows.first.id}-0')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('表格操作'));
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('下移一行')).dy,
        greaterThan(t.getTopLeft(find.text('删除表格')).dy),
      );
      await t.tap(find.text('下移一行'));
      await t.pumpAndSettle();
      expect(c.document.toPlainText(), '前文\n\n\uFFFC\n后文\n');
      c.undo();
      await t.pumpAndSettle();
      expect(c.document.toDelta().toJson(), original);
      await t.tap(find.byKey(ValueKey('table-cell-${table.rows.first.id}-0')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('表格操作'));
      await t.pumpAndSettle();
      await t.tap(find.text('删除表格'));
      await t.pumpAndSettle();
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(c.document.toDelta().toJson(), original);
      await t.tap(find.byKey(ValueKey('table-cell-${table.rows.first.id}-0')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('表格操作'));
      await t.pumpAndSettle();
      await t.tap(find.text('删除表格'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, '删除'));
      await t.pumpAndSettle();
      expect(c.document.toPlainText(), '前文\n后文\n');
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('撤回'));
      await t.pumpAndSettle();
      expect(c.document.toDelta().toJson(), original);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  test(
    'Two backspaces remove even a final table while retaining terminal newline',
    () {
      final table = JournalTableData.empty(3, 2);
      final c = JournalController(
        document: quill.Document.fromJson([
          {
            'insert': {'table': table.encode()},
          },
          {'insert': '\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 1),
      );
      expect(c.handleTableBackspace(), true);
      expect(c.selection.isCollapsed, false);
      expect(c.handleTableBackspace(), true);
      expect(c.document.toPlainText(), '\n');
      c.dispose();
    },
  );
  test(
    'Removed checklist shortcuts stay literal and old checklist content becomes bullets',
    () {
      for (final text in ['[ ] ', '[x] ']) {
        final c = JournalController(
          document: quill.Document.fromJson([
            {'insert': '$text\n'},
          ]),
          selection: TextSelection.collapsed(offset: text.length),
        );
        expect(applyJournalShortcut(c), false);
        expect(c.document.toPlainText(), '$text\n');
        c.dispose();
      }
      final note = entry(
        '旧选框',
        document: [
          {'insert': '旧内容'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
        ],
      );
      expect(note.document.last['attributes']['list'], 'bullet');
      expect(note.content, '旧内容');
    },
  );
}
