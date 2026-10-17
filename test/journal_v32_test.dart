import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_image_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_shortcuts.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/widgets/journal_table.dart';
import 'package:inch_light/widgets/position_border.dart';

JournalEntry note(String id, {List<dynamic>? document, String? folder}) =>
    JournalEntry(
      id: id,
      title: id,
      document:
          document ??
          [
            {'insert': '正文\n'},
          ],
      collectionId: folder,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<AppProvider> mount(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
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

  test(
    'Bottom is exclusive with pin and survives import; deleted folder can preserve or remove notes',
    () async {
      final p = AppProvider();
      await p.ready;
      await p.addJournalCollection('合集');
      final id = p.journalCollections.single.id;
      await p.saveJournalEntry(note('置底', folder: id).copyWith(isBottom: true));
      await p.saveJournalEntry(note('普通'));
      expect(p.journalEntries.last.id, '置底');
      final bottom = p.journalEntries.last;
      expect(bottom.copyWith(isPinned: true).isBottom, isFalse);
      expect(
        bottom.copyWith(isPinned: true).copyWith(isBottom: true).isPinned,
        isFalse,
      );
      expect(await p.importData(p.exportData()), isTrue);
      expect(p.journalEntries.last.isBottom, isTrue);
      await p.removeJournalCollection(id);
      expect(p.journalCollections, isEmpty);
      expect(p.journalEntries.last.collectionId, isNull);
      await p.addJournalCollection('第二个');
      final second = p.journalCollections.single.id;
      await p.saveJournalEntry(
        bottom.copyWith(collectionId: second, move: true),
      );
      await p.removeJournalCollection(second, deleteEntries: true);
      expect(p.journalEntries.single.id, '普通');
      p.dispose();
    },
  );

  test(
    'Inline software shortcuts cover bold italic strike highlight and escaped markers',
    () {
      for (final (syntax, text, key, value)
          in <(String, String, String, Object)>[
            ('**加粗**', '加粗', 'bold', true),
            ('__加粗__', '加粗', 'bold', true),
            ('*倾斜*', '倾斜', 'italic', true),
            ('~~删除~~', '删除', 'strike', true),
            ('==高亮==', '高亮', 'background', '#FFF2B3'),
            ('`代码`', '代码', 'code', true),
          ]) {
        final c = quill.QuillController(
          document: quill.Document.fromJson([
            {'insert': '$syntax\n'},
          ]),
          selection: TextSelection.collapsed(offset: syntax.length),
        );
        expect(applyJournalShortcut(c), isTrue, reason: syntax);
        expect(c.document.toPlainText(), '$text\n');
        expect(c.document.toDelta().toJson().first['attributes'][key], value);
        c.dispose();
      }
      final c = quill.QuillController(
        document: quill.Document.fromJson([
          {
            'insert':
                r'\**原文**'
                '\n',
          },
        ]),
        selection: const TextSelection.collapsed(offset: 7),
      );
      expect(applyJournalShortcut(c), isFalse);
      c.dispose();
      for (final (syntax, attr, value) in [
        ('## ', 'header', 2),
        ('- ', 'list', 'bullet'),
        ('1. ', 'list', 'ordered'),
        ('> ', 'blockquote', true),
      ]) {
        final c = quill.QuillController(
          document: quill.Document.fromJson([
            {'insert': '$syntax\n'},
          ]),
          selection: TextSelection.collapsed(offset: syntax.length),
        );
        expect(applyJournalShortcut(c), isTrue);
        expect(c.document.toDelta().toJson().last['attributes'][attr], value);
        c.dispose();
      }
    },
  );

  test(
    'Table backspace selects first and deletes second without merging adjacent prose',
    () {
      final table = JournalTableData.empty(3, 2);
      final c = JournalController(
        document: quill.Document.fromJson([
          {'insert': '前文\n'},
          {
            'insert': {'table': table.encode()},
          },
          {'insert': '\n\n后文\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 5),
      );
      c.replaceText(4, 1, '', const TextSelection.collapsed(offset: 4));
      expect(c.pendingTable, 3);
      expect(c.selection, const TextSelection(baseOffset: 3, extentOffset: 4));
      expect(
        c.document.toDelta().toJson().any((op) => op['insert'] is Map),
        isTrue,
      );
      c.replaceText(3, 1, '', const TextSelection.collapsed(offset: 3));
      expect(c.document.toPlainText(), '前文\n\n后文\n');
      expect(c.pendingTable, isNull);
      c.dispose();
    },
  );

  testWidgets(
    'Folder viewport keeps margins, export separates notes, bottom reserves position icon',
    (t) async {
      final p = await mount(t, const JournalPage());
      final work = () async {
        for (var i = 0; i < 8; i++) {
          await p.addJournalCollection('合集$i');
        }
        await p.saveJournalEntry(note('第一条'));
        await p.saveJournalEntry(note('第二条').copyWith(isBottom: true));
      }();
      await t.pumpAndSettle();
      await work;
      expect(t.getRect(find.byKey(const ValueKey('collection-tabs'))).left, 16);
      expect(
        t.getRect(find.byKey(const ValueKey('collection-tabs'))).right,
        374,
      );
      final material = t.widget<Material>(
        find.byKey(const ValueKey('note-card-第二条')),
      );
      expect((material.shape! as PositionBorder).bottom, isTrue);
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        },
      );
      await t.tap(find.byTooltip('批量导出 Markdown'));
      await t.pump();
      expect(copied, journalCollectionToMarkdown(p.journalEntries));
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      await t.ensureVisible(find.text('合集7'));
      await t.pumpAndSettle();
      await t.longPress(find.text('合集7'));
      await t.pumpAndSettle();
      expect(find.byTooltip('置顶'), findsNothing);
      await t.tap(find.text('删除合集'));
      await t.pumpAndSettle();
      await t.tap(find.text('保留笔记，删除合集'));
      await t.pumpAndSettle();
      expect(p.journalCollections.any((e) => e.title == '合集7'), isFalse);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Multiline list markers align to first line; item spacing exceeds wrapped spacing',
    (t) async {
      final long = '列表文字较长，应该自动换行而不影响第一行标记的位置。' * 2;
      final p = await mount(
        t,
        JournalEditorPage(
          entry: note(
            '排版',
            document: [
              {'insert': long},
              {
                'insert': '\n',
                'attributes': {'list': 'ordered'},
              },
              {'insert': '第二项'},
              {
                'insert': '\n',
                'attributes': {'list': 'ordered'},
              },
              {'insert': '选框文字'},
              {
                'insert': '\n',
                'attributes': {'list': 'unchecked'},
              },
            ],
          ),
        ),
      );
      Finder rich(String text) => find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == text,
      );
      final body = rich(long);
      expect(
        t.getTopLeft(find.text('1.', findRichText: true)).dy,
        closeTo(t.getTopLeft(body).dy, .01),
      );
      final end = t.getBottomLeft(body).dy;
      expect(t.getTopLeft(rich('第二项')).dy - end, closeTo(5, .01));
      expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Only headings following prose gain top margin, including aligned headings',
    (t) async {
      final p = await mount(
        t,
        JournalEditorPage(
          entry: note(
            '标题间距',
            document: [
              {'insert': '首标题'},
              {
                'insert': '\n',
                'attributes': {'header': 1},
              },
              {'insert': '连续标题'},
              {
                'insert': '\n',
                'attributes': {'header': 2},
              },
              {'insert': '正文'},
              {'insert': '\n'},
              {'insert': '正文后标题'},
              {
                'insert': '\n',
                'attributes': {'header': 3},
              },
              {'insert': '再一段'},
              {'insert': '\n'},
              {'insert': '居中标题'},
              {
                'insert': '\n',
                'attributes': {'header': 2, 'align': 'center'},
              },
            ],
          ),
        ),
      );
      Finder rich(String text) => find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == text,
      );
      expect(
        t.getTopLeft(rich('连续标题')).dy - t.getBottomLeft(rich('首标题')).dy,
        closeTo(10, .01),
      );
      expect(
        t.getTopLeft(rich('正文后标题')).dy - t.getBottomLeft(rich('正文')).dy,
        closeTo(26, .01),
      );
      expect(
        t.getTopLeft(rich('居中标题')).dy - t.getBottomLeft(rich('再一段')).dy,
        closeTo(42, .01),
      );
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Software keyboard completes inline formats and backspace selects then removes table',
    (t) async {
      final p = await mount(t, const JournalEditorPage());
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      editor.focusNode.requestFocus();
      await t.pump();
      for (final (text, key) in [
        ('**加粗**', 'bold'),
        ('*倾斜*', 'italic'),
        ('~~删除~~', 'strike'),
        ('==高亮==', 'background'),
      ]) {
        final old = editor.controller.document;
        editor.controller.document = quill.Document();
        old.close();
        editor.controller.updateSelection(
          const TextSelection.collapsed(offset: 0),
          quill.ChangeSource.local,
        );
        await t.pump();
        for (var i = 1; i <= text.length; i++) {
          t.testTextInput.updateEditingValue(
            TextEditingValue(
              text: '${text.substring(0, i)}\n',
              selection: TextSelection.collapsed(offset: i),
            ),
          );
          await t.pump();
        }
        expect(
          editor.controller.document.toPlainText(),
          isNot(contains(text[0])),
        );
        expect(
          editor.controller.document
              .toDelta()
              .toJson()
              .first['attributes'][key],
          isNotNull,
        );
      }
      final table = JournalTableData.empty(3, 2);
      final old = editor.controller.document;
      editor.controller.document = quill.Document.fromJson([
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n\n'},
      ]);
      old.close();
      editor.controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        quill.ChangeSource.local,
      );
      await t.pump();
      final before = editor.controller.document.toPlainText();
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: before.replaceRange(1, 2, ''),
          selection: const TextSelection.collapsed(offset: 1),
        ),
      );
      await t.pump();
      expect(editor.controller.selection.isCollapsed, isFalse);
      final selection = editor.controller.selection;
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: editor.controller.document.toPlainText().replaceRange(
            selection.start,
            selection.end,
            '',
          ),
          selection: TextSelection.collapsed(offset: selection.start),
        ),
      );
      await t.pump();
      expect(find.byType(JournalTable), findsNothing);
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets('Table end has no giant cursor and first delete dims the embed', (
    t,
  ) async {
    final table = JournalTableData.empty(3, 2);
    final p = await mount(
      t,
      JournalEditorPage(
        entry: note(
          '表格',
          document: [
            {
              'insert': {'table': table.encode()},
            },
            {'insert': '\n\n'},
          ],
        ),
      ),
    );
    final editor = t.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    editor.focusNode.requestFocus();
    editor.controller.updateSelection(
      const TextSelection.collapsed(offset: 1),
      quill.ChangeSource.local,
    );
    await t.pump();
    expect(
      t
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .config
          .showCursor,
      isFalse,
    );
    editor.controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      quill.ChangeSource.local,
    );
    editor.controller.replaceText(
      1,
      1,
      '',
      const TextSelection.collapsed(offset: 1),
    );
    await t.pump();
    final opacity = find
        .ancestor(of: find.byType(JournalTable), matching: find.byType(Opacity))
        .first;
    expect(t.widget<Opacity>(opacity).opacity, .4);
    editor.controller.replaceText(
      0,
      1,
      '',
      const TextSelection.collapsed(offset: 0),
    );
    await t.pump();
    expect(find.byType(JournalTable), findsNothing);
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets(
    'Image export renders entire content beyond viewport as a complete PNG',
    (t) async {
      final p = await mount(
        t,
        JournalImagePage(
          entry: note(
            '图片标题',
            document: [
              {'insert': '长图正文\n' * 50},
            ],
          ),
        ),
      );
      final capture = find
          .ancestor(
            of: find.byType(quill.QuillEditor),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      final boundary = t.renderObject<RenderRepaintBoundary>(capture);
      expect(boundary.size.height, greaterThan(844));
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(png!.buffer.asUint8List().take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
        expect(image.height, greaterThan(844));
        image.dispose();
      });
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
