import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/screens/cycle_page.dart';
import 'package:inch_light/widgets/journal_table.dart';
import 'package:inch_light/widgets/journal_tags.dart';
import 'package:inch_light/utils/journal_markdown.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  JournalEntry note(
    String id, {
    String? folder,
    int day = 1,
    bool pinned = false,
  }) => JournalEntry(
    id: id,
    title: id,
    document: [
      {'insert': '正文\n'},
    ],
    tags: ['标签'],
    collectionId: folder,
    isPinned: pinned,
    titleBold: true,
    createdAt: DateTime(2026, 10, day),
    updatedAt: DateTime(2026, 10, day),
  );
  Future<AppProvider> mount(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(home: page),
      ),
    );
    await t.pumpAndSettle();
    return p;
  }

  Future<void> close(WidgetTester t, AppProvider p) async {
    await t.pumpWidget(const SizedBox());
    p.dispose();
  }

  test(
    'Pin, move, recency and title weight survive storage and old data',
    () async {
      final p = AppProvider();
      await p.ready;
      await p.addJournalCollection('甲');
      final a = p.journalCollections.single.id;
      await p.addJournalCollection('乙');
      final b = p.journalCollections.first.id;
      await p.saveJournalEntry(note('older', folder: a, day: 20));
      await p.saveJournalEntry(note('newer', folder: b, day: 21));
      expect(p.journalCollections.first.id, b);
      await p.renameJournalCollection(a, '甲');
      expect(p.journalCollections.first.id, b);
      await p.saveJournalEntry(
        p.journalEntries.last.copyWith(
          isPinned: true,
          collectionId: b,
          move: true,
        ),
      );
      expect(p.journalEntries.first.id, 'older');
      final data = p.exportData();
      p.dispose();
      final restored = AppProvider();
      await restored.ready;
      expect(restored.journalEntries.first.titleBold, isTrue);
      expect(restored.journalEntries.first.collectionId, b);
      expect(
        restored.journalCollections.first.toJson().containsKey('isPinned'),
        isFalse,
      );
      expect(await restored.importData(data), isTrue);
      final legacy = note('legacy').toJson()
        ..remove('isPinned')
        ..remove('titleBold');
      expect(JournalEntry.fromJson(legacy).isPinned, isFalse);
      restored.dispose();
    },
  );

  testWidgets(
    'Tabs, pin, move, collection export and swipe delete work together',
    (t) async {
      final p = await mount(t, const JournalPage());
      final setup = () async {
        await p.addJournalCollection('工作');
        await p.saveJournalEntry(note('笔记甲'));
        await p.saveJournalEntry(note('笔记乙', day: 2));
      }();
      await t.pumpAndSettle();
      await setup;
      expect(
        t.getTopLeft(find.text('默认')).dx,
        lessThan(t.getTopLeft(find.text('工作')).dx),
      );
      final card = find.byKey(const ValueKey('note-card-笔记甲'));
      final tags = find.descendant(
        of: card,
        matching: find.byType(JournalTags),
      );
      final text = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('字') ?? false),
        ),
      );
      expect(t.getSize(tags).height, closeTo(t.getSize(text).height, .01));
      await t.longPress(card);
      await t.pumpAndSettle();
      await t.tap(find.text('置顶'));
      await t.pumpAndSettle();
      expect(p.journalEntries.first.id, '笔记甲');
      await t.longPress(card);
      await t.pumpAndSettle();
      await t.tap(find.text('移动到合集'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(SimpleDialogOption, '工作'));
      await t.pumpAndSettle();
      expect(find.text('笔记甲'), findsNothing);
      await t.tap(find.text('工作'));
      await t.pumpAndSettle();
      expect(find.text('笔记甲'), findsOneWidget);
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await t.tap(find.byTooltip('批量导出 Markdown'));
      await t.pump();
      expect(copied, contains('# 笔记甲'));
      expect(copied, isNot(contains('笔记乙')));
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      await t.drag(
        find.byKey(const ValueKey('dismiss-note-笔记甲')),
        const Offset(-350, 0),
      );
      await t.pumpAndSettle();
      expect(p.journalEntries.any((e) => e.id == '笔记甲'), isFalse);
      await close(t, p);
    },
  );

  testWidgets(
    'Software keyboard Markdown, title bold and fixed heading weights',
    (t) async {
      final p = await mount(t, const JournalEditorPage());
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      var editor = t.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
      editor.focusNode.requestFocus();
      await t.pump();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '##\n',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await t.pump();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '## \n',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await t.pumpAndSettle();
      expect(editor.controller.document.toDelta().toJson().last['attributes'], {
        'header': 2,
      });
      editor.controller.replaceText(
        0,
        0,
        '小标题',
        const TextSelection.collapsed(offset: 3),
      );
      await t.pump();
      final line = editor.controller.document.root.children.first as quill.Line;
      final span =
          editor.config.textSpanBuilder(
                t.element(find.byType(quill.QuillEditor)),
                line.children.first,
                0,
                '小标题',
                const TextStyle(fontWeight: FontWeight.w700),
                null,
              )
              as TextSpan;
      expect(span.style!.fontWeight, FontWeight.w600);
      expect(editor.config.customStyles!.paragraph!.style.fontSize, 18);
      expect(
        editor.config.customStyles!.quote!.verticalSpacing,
        editor.config.customStyles!.paragraph!.verticalSpacing,
      );
      await t.tap(find.byKey(const ValueKey('record-title')));
      await t.enterText(find.byKey(const ValueKey('record-title')), '标题');
      await t.tap(find.byKey(const ValueKey('format-加粗')));
      await t.pump();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('record-title')))
            .style!
            .fontWeight,
        FontWeight.w600,
      );
      await t.tap(find.byTooltip('确定'));
      await t.pumpAndSettle();
      expect(p.journalEntries.single.titleBold, isTrue);
      expect(journalToMarkdown(p.journalEntries.single), contains('### 小标题'));
      final c = editor.controller;
      c.document = quill.Document();
      c.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
      editor.focusNode.requestFocus();
      await t.pump();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '-\n',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await t.pump();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- \n',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await t.pumpAndSettle();
      expect(c.document.toDelta().toJson().last['attributes'], {
        'list': 'bullet',
      });
      await close(t, p);
    },
  );

  test('Table width adapts within the viewport and bounds wide columns', () {
    var data = JournalTableData.empty(3, 2);
    const scaler = TextScaler.noScaling;
    expect(journalTableWidths(data, 340, scaler), [170, 170]);
    data = data.edit(data.rows.first.id, 0, '很多文字' * 15);
    var widths = journalTableWidths(data, 340, scaler);
    expect(widths[0], greaterThan(170));
    expect(widths.reduce((a, b) => a + b), closeTo(340, .01));
    data = data.edit(data.rows.first.id, 1, '很多文字' * 15);
    expect(journalTableWidths(data, 340, scaler), [170, 170]);
    data = JournalTableData.empty(3, 5);
    widths = journalTableWidths(data, 340, scaler);
    expect(widths, everyElement(106));
    data = data.edit(data.rows.first.id, 0, '很多文字' * 30);
    expect(journalTableWidths(data, 340, scaler).first, 196);
  });

  testWidgets('Calendar ordering persists and settings credit Symplatt', (
    t,
  ) async {
    final p = await mount(t, const SettingsPage());
    expect(find.text('笔记顺序'), findsNothing);
    expect(find.text('时历顺序'), findsOneWidget);
    await t.tap(find.text('周期在上'));
    await t.pumpAndSettle();
    expect(p.countdownsFirst, isFalse);
    await t.ensureVisible(find.text('© 2026 Symplatt · 版权所有'));
    expect(find.text('© 2026 Symplatt · 版权所有'), findsOneWidget);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: CyclePage()),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(find.text('周期')).dy,
      lessThan(t.getTopLeft(find.text('倒计时')).dy),
    );
    await close(t, p);
    final restored = await t.runAsync(() async {
      final value = AppProvider();
      await value.ready;
      return value;
    });
    expect(restored!.countdownsFirst, isFalse);
    restored.dispose();
  });
  testWidgets(
    'Metadata scrolls with prose and list markers share its left edge',
    (t) async {
      final entry = JournalEntry(
        id: 'scroll',
        title: '随正文滚动',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        document: [
          {'insert': '正文\n'},
          {'insert': '无序事项'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': '有序事项'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': '选框事项'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          {'insert': '长正文\n' * 60},
        ],
      );
      final p = await mount(t, JournalEditorPage(entry: entry));
      final left = t.getTopLeft(find.byKey(const ValueKey('record-title'))).dx;
      expect(
        t.getTopLeft(find.text('•', findRichText: true)).dx,
        closeTo(left, .01),
      );
      expect(
        t.getTopLeft(find.text('1.', findRichText: true)).dx,
        closeTo(left, .01),
      );
      expect(
        t.getTopLeft(find.byIcon(Icons.check_box_outline_blank)).dx,
        closeTo(left, .01),
      );
      final before = t
          .getTopLeft(find.byKey(const ValueKey('record-metadata')))
          .dy;
      await t.drag(
        find.byKey(const ValueKey('record-page-scroll')),
        const Offset(0, -500),
      );
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.byKey(const ValueKey('record-metadata'))).dy,
        lessThan(before - 100),
      );
      await close(t, p);
    },
  );
}
