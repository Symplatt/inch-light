import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/main_screen.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/screens/cycle_page.dart';
import 'package:inch_light/widgets/journal_table.dart';
import 'package:inch_light/widgets/section_heading.dart';
import 'package:inch_light/utils/journal_markdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppProvider> mount(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> unmount(WidgetTester tester, AppProvider provider) async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  }

  testWidgets(
    'Table creation, cell typing, newline row insertion and undo survive persistence',
    (tester) async {
      final provider = await mount(tester, const JournalEditorPage());
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('format-表格')));
      await tester.tap(find.byKey(const ValueKey('format-表格')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('table-rows')))
            .controller!
            .text,
        '3',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('table-columns')))
            .controller!
            .text,
        '2',
      );
      await tester.enterText(find.byKey(const ValueKey('table-rows')), '2');
      await tester.enterText(find.byKey(const ValueKey('table-columns')), '2');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalTable), findsOneWidget);
      var table = tester.widget<JournalTable>(find.byType(JournalTable)).data;
      final firstId = table.rows.first.id;
      final tableEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      tableEditor.focusNode.requestFocus();
      tableEditor.controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
      await tester.pump();
      expect(
        tester
            .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
            .config
            .showCursor,
        isFalse,
      );
      final secondId = table.rows.last.id;
      Finder cell(String row, int c) =>
          find.byKey(ValueKey('table-cell-$row-$c'));
      await tester.enterText(cell(firstId, 0), '表头');
      await tester.pump();
      await tester.enterText(cell(secondId, 1), '内容\n');
      await tester.pumpAndSettle();
      table = tester.widget<JournalTable>(find.byType(JournalTable)).data;
      expect(table.columns, 2);
      expect(table.rows.length, 3);
      expect(table.rows[1].cells[1], '内容');
      final next = tester.widget<TextField>(cell(table.rows.last.id, 0));
      expect(next.focusNode!.hasFocus, isTrue);
      expect(next.textAlign, TextAlign.left);
      await tester.enterText(cell(table.rows.last.id, 0), '追加');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('撤回'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<JournalTable>(find.byType(JournalTable))
            .data
            .rows
            .last
            .cells
            .first,
        '',
      );
      await tester.tap(find.byTooltip('取消撤回'));
      await tester.pumpAndSettle();
      final saved = provider.journalEntries.single;
      expect(saved.wordCount, 6);
      expect(JournalEntry.fromJson(saved.toJson()).content, saved.content);
      expect(
        journalToMarkdown(saved),
        contains('| 表头 |  |\n| :--- | :--- |\n|  | 内容 |\n| 追加 |  |'),
      );
      final header = tester.widget<TextField>(cell(firstId, 0));
      expect(header.style!.fontWeight, FontWeight.w600);
      final editor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      expect(
        header.style!.fontSize,
        lessThan(editor.config.customStyles!.h3!.style.fontSize!),
      );
      expect(
        editor.config.customStyles!.h1!.style.fontSize,
        lessThanOrEqualTo(
          tester
              .widget<TextField>(find.byKey(const ValueKey('record-title')))
              .style!
              .fontSize!,
        ),
      );
      final exported = provider.exportData();
      await tester.runAsync(() async {
        final restored = AppProvider();
        await restored.ready;
        expect(await restored.importData(exported), isTrue);
        expect(restored.journalEntries.single.content, saved.content);
        restored.dispose();
      });
      expect(tester.takeException(), isNull);
      await unmount(tester, provider);
    },
  );

  testWidgets('Table hardware Enter inserts directly below the current row', (
    tester,
  ) async {
    var data = JournalTableData.empty(2, 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => JournalTable(
              data: data,
              onChanged: (value) => update(() => data = value),
            ),
          ),
        ),
      ),
    );
    final headerId = data.rows.first.id;
    await tester.tap(find.byKey(ValueKey('table-cell-$headerId-1')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(data.rows.length, 3);
    expect(
      tester
          .widget<TextField>(
            find.byKey(ValueKey('table-cell-${data.rows[1].id}-0')),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets(
    'Compact cards show subtle tags without extra height, preserve order and clear both searches',
    (tester) async {
      final provider = await mount(tester, const JournalPage());
      final setup = () async {
        await provider.addJournalCollection('合集甲');
        await provider.saveJournalEntry(
          JournalEntry(
            id: 'root',
            title: '长标题' * 20,
            document: [
              {'insert': '不展示的正文\n'},
            ],
            tags: ['标签甲', '很长的标签乙' * 8, '标签丙'],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        await provider.saveJournalEntry(
          JournalEntry(
            id: 'nested',
            title: '合集笔记',
            tags: ['合集标签'],
            collectionId: provider.journalCollections.single.id,
            document: [
              {'insert': '\n'},
            ],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
      }();
      await tester.pumpAndSettle();
      await setup;
      final noteCard = find.byKey(const ValueKey('note-card-root'));
      expect(
        tester.widget<Text>(find.text('长标题' * 20)).overflow,
        TextOverflow.ellipsis,
      );
      expect(find.text('不展示的正文'), findsNothing);
      expect(find.text('标签甲'), findsOneWidget);
      final tagScroll = find.descendant(
        of: noteCard,
        matching: find.byType(SingleChildScrollView),
      );
      expect(
        tester.getRect(tagScroll).right,
        closeTo(tester.getRect(find.text('长标题' * 20)).right, .01),
      );
      expect(tester.takeException(), isNull);
      final titleStyle = tester.widget<Text>(find.text('长标题' * 20)).style!;
      final tagStyle = tester.widget<Text>(find.text('标签甲')).style!;
      expect(titleStyle.fontSize, 17);
      expect(titleStyle.fontWeight, FontWeight.w500);
      expect(titleStyle.color, const Color(0xFF3D3D3D));
      expect(tester.widget<Text>(find.text('合集甲')).style, titleStyle);
      expect(tagStyle.fontSize, 10);
      expect(tagStyle.color, const Color(0xFF767676));
      await tester.enterText(
        find.byKey(const ValueKey('record-search')),
        '无结果',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(find.text('合集甲'), findsOneWidget);
      await tester.tap(find.text('合集甲'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-search')),
        '无结果',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(find.text('合集笔记'), findsOneWidget);
      expect(find.text('合集标签'), findsOneWidget);
      expect(tester.widget<Text>(find.text('合集笔记')).style, titleStyle);
      expect(tester.widget<Text>(find.text('合集标签')).style, tagStyle);
      await unmount(tester, provider);
    },
  );

  testWidgets('Each navigation module is restored on a fresh launch', (
    tester,
  ) async {
    var provider = await mount(tester, const MainScreen());
    for (final label in ['记录', '时历', '设置', '待办']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      final selected = tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex;
      await unmount(tester, provider);
      provider = await mount(tester, const MainScreen());
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        selected,
      );
    }
    await unmount(tester, provider);
  });

  testWidgets(
    'Calendar and settings section headings share geometry and style',
    (tester) async {
      final provider = await mount(tester, const CyclePage());
      final calendarPosition = tester.getTopLeft(find.text('倒计时'));
      final calendarStyle = tester.widget<Text>(find.text('倒计时')).style;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('事项顺序')), calendarPosition);
      expect(tester.widget<Text>(find.text('事项顺序')).style, calendarStyle);
      expect(find.byType(SectionHeading), findsNWidgets(4));
      await unmount(tester, provider);
    },
  );
}
