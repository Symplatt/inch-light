import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_image_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/utils/journal_shortcuts.dart';
import 'package:inch_light/widgets/journal_collection_dialog.dart';
import 'package:inch_light/widgets/journal_export_icon.dart';
import 'package:inch_light/widgets/journal_format_icon.dart';

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
      tags: ['灵感', '整理'],
      createdAt: DateTime(2026, 10, 13),
      updatedAt: DateTime(2026, 10, 13, 10, 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('All journal action glyphs share painted bounds and size', (
    t,
  ) async {
    final bounds = <Rect>[];
    for (final symbol in JournalActionSymbol.values) {
      final key = GlobalKey();
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: IconTheme(
                data: const IconThemeData(color: Colors.black),
                child: JournalActionIcon(symbol),
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(JournalActionIcon)), const Size(24, 24));
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 4);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var left = image.width, top = image.height, right = -1, bottom = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (data.getUint8((y * image.width + x) * 4 + 3) < 32) continue;
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
        bounds.add(
          Rect.fromLTRB(left / 4, top / 4, (right + 1) / 4, (bottom + 1) / 4),
        );
        image.dispose();
      });
    }
    for (final rect in bounds) {
      expect(rect.left, closeTo(bounds.first.left, .25));
      expect(rect.top, closeTo(bounds.first.top, .25));
      expect(rect.right, closeTo(bounds.first.right, .25));
      expect(rect.bottom, closeTo(bounds.first.bottom, .25));
    }
  });

  testWidgets(
    'Format glyphs use consistent visible height and vertical center',
    (t) async {
      for (final symbol in JournalFormatSymbol.values) {
        final key = GlobalKey();
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: JournalFormatIcon(symbol),
              ),
            ),
          ),
        );
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 4);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var top = image.height, bottom = -1;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (data.getUint8((y * image.width + x) * 4 + 3) < 32) continue;
              if (y < top) top = y;
              if (y > bottom) bottom = y;
            }
          }
          expect((top + bottom + 1) / 8, closeTo(12, .5), reason: symbol.name);
          expect(
            (bottom + 1 - top) / 4,
            closeTo(symbol == JournalFormatSymbol.boldWide ? 15.5 : 18, 1),
            reason: symbol.name,
          );
          image.dispose();
        });
      }
    },
  );

  Future<void> mount(WidgetTester t, AppProvider p, Widget page) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        child: ChangeNotifierProvider.value(
          value: p,
          child: Builder(
            builder: (context) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: (const MyApp().build(context) as MaterialApp).theme,
              home: page,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  test(
    'Per-note recovery expires independently, persists across restart and preserves all fields',
    () async {
      var now = DateTime(2026, 10, 13);
      var p = AppProvider(journalNow: () => now);
      await p.ready;
      await p.addJournalCollection('合集');
      final folder = p.journalCollections.single.id;
      for (final id in ['一', '二', '三']) {
        await p.saveJournalEntry(
          note(id, folder: folder).copyWith(isBottom: true),
        );
      }
      await p.removeJournalEntry('一', recoverable: true);
      now = now.add(const Duration(seconds: 20));
      await p.removeJournalEntry('二', recoverable: true);
      now = now.add(const Duration(seconds: 50));
      await p.removeJournalEntry('三', recoverable: true);
      expect(p.recoverableJournalCount, 2);
      p.dispose();
      p = AppProvider(journalNow: () => now);
      await p.ready;
      expect(await p.restoreRecentJournalEntries(), 2);
      expect(p.journalEntries.map((e) => e.id).toSet(), {'二', '三'});
      for (final entry in p.journalEntries) {
        expect(
          entry.toJson(),
          note(entry.id, folder: folder).copyWith(isBottom: true).toJson(),
        );
      }
      expect(p.recoverableJournalCount, 0);
      p.dispose();
    },
  );

  test(
    'Recovery checks confirmation time; missing collection falls back to default',
    () async {
      var now = DateTime(2026);
      final p = AppProvider(journalNow: () => now);
      await p.ready;
      await p.addJournalCollection('合集');
      final folder = p.journalCollections.single.id;
      await p.saveJournalEntry(note('过期', folder: folder));
      await p.removeJournalEntry('过期', recoverable: true);
      now = now.add(const Duration(seconds: 60));
      expect(await p.restoreRecentJournalEntries(), 0);
      await p.saveJournalEntry(note('恢复', folder: folder));
      await p.removeJournalEntry('恢复', recoverable: true);
      await p.removeJournalCollection(folder);
      expect(await p.restoreRecentJournalEntries(), 1);
      expect(p.journalEntries.single.collectionId, isNull);
      p.dispose();
    },
  );

  test('Collection Markdown keeps every title on its own heading line', () {
    final result = journalCollectionToMarkdown([
      note(
        '甲',
        document: [
          {'insert': '尾段\n'},
        ],
      ),
      note(
        '乙',
        document: [
          {'insert': '列表'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
        ],
      ),
      note(
        '丙',
        document: [
          {'insert': '\n'},
        ],
      ),
    ]);
    expect(result, '# 甲\n\n尾段\n\n# 乙\n\n1. 列表\n\n# 丙');
  });

  test('Scripts and inline code shortcut and export preserve syntax', () {
    for (final (syntax, attribute, value) in [
      ('^上标^', 'script', 'super'),
      ('~下标~', 'script', 'sub'),
      ('`a_b*`', 'code', true),
    ]) {
      final c = JournalController(
        document: quill.Document.fromJson([
          {'insert': '$syntax\n'},
        ]),
        selection: TextSelection.collapsed(offset: syntax.length),
      );
      expect(applyJournalShortcut(c), isTrue);
      expect(
        c.document.toDelta().toJson().first['attributes'][attribute],
        value,
      );
      expect(
        journalToMarkdown(note('格式', document: c.document.toDelta().toJson())),
        '# 格式\n\n$syntax',
      );
      c.dispose();
    }
    expect(
      journalToMarkdown(
        note(
          '代码',
          document: [
            {
              'insert': 'a`b',
              'attributes': {'code': true},
            },
            {'insert': '\n'},
          ],
        ),
      ),
      '# 代码\n\n``a`b``',
    );
    final escaped = JournalController(
      document: quill.Document.fromJson([
        {
          'insert':
              r'\^原文^'
              '\n',
        },
      ]),
      selection: const TextSelection.collapsed(offset: 6),
    );
    expect(applyJournalShortcut(escaped), isFalse);
    escaped.dispose();
  });

  test(
    'Backspace collapses leading empty lines only and preserves following heading and inline styles',
    () {
      for (final offset in [0, 1, 2]) {
        final c = JournalController(
          document: quill.Document.fromJson([
            {'insert': '\n\n\n'},
            {
              'insert': '首行',
              'attributes': {'bold': true},
            },
            {
              'insert': '\n',
              'attributes': {'header': 2},
            },
            {'insert': '\n后文\n'},
          ]),
          selection: TextSelection.collapsed(offset: offset),
        );
        if (offset == 0) {
          c.handleDelete(0, false);
        } else {
          c.replaceText(
            offset - 1,
            1,
            '',
            TextSelection.collapsed(offset: offset - 1),
          );
        }
        expect(c.document.toPlainText(), '首行\n\n后文\n');
        expect(c.document.toDelta().toJson().first['attributes']['bold'], true);
        expect(c.document.toDelta().toJson()[1]['attributes']['header'], 2);
        expect(c.selection.baseOffset, 0);
        c.dispose();
      }
      for (final (text, offset) in [
        ('正文\n\n后文\n', 3),
        ('\n\n', 0),
        ('\n首行\n', 1),
      ]) {
        final c = JournalController(
          document: quill.Document.fromJson([
            {'insert': text},
          ]),
          selection: TextSelection.collapsed(offset: offset),
        );
        expect(c.clearLeadingEmptyLines(), false);
        expect(c.document.toPlainText(), text);
        c.dispose();
      }
    },
  );

  testWidgets(
    'Swipe only right to left; restore uses confirmation and leaves expired notes deleted',
    (t) async {
      var now = DateTime(2026);
      final p = AppProvider(journalNow: () => now);
      await t.runAsync(() async {
        await p.ready;
        await p.saveJournalEntry(note('滑动'));
      });
      await mount(t, p, const JournalPage());
      expect(
        t.getCenter(find.byTooltip('新建合集')).dx,
        greaterThan(t.getCenter(find.byTooltip('批量导出 Markdown')).dx),
      );
      expect(
        t.getTopLeft(find.byKey(const ValueKey('note-folder-default'))).dx,
        16,
      );
      final card = find.byKey(const ValueKey('dismiss-note-滑动'));
      await t.drag(card, const Offset(350, 0));
      await t.pumpAndSettle();
      expect(p.journalEntries, hasLength(1));
      await t.tap(find.byTooltip('退出多选'));
      await t.pumpAndSettle();
      await t.drag(card, const Offset(-350, 0));
      await t.pumpAndSettle();
      expect(p.journalEntries, isEmpty);
      expect(find.text('删除记录？'), findsNothing);
      expect(find.byTooltip('恢复'), findsOneWidget);
      final actions = t.widgetList<JournalActionIcon>(
        find.byType(JournalActionIcon),
      );
      expect(actions, hasLength(3));
      expect(actions.map((a) => a.symbol), [
        JournalActionSymbol.restore,
        JournalActionSymbol.exportAll,
        JournalActionSymbol.folder,
      ]);
      final rects = find
          .byType(JournalActionIcon)
          .evaluate()
          .map((e) => t.getRect(find.byWidget(e.widget)))
          .toList();
      expect(rects.map((r) => r.top).toSet(), hasLength(1));
      expect(rects.map((r) => r.bottom).toSet(), hasLength(1));
      await t.tap(find.byTooltip('恢复'));
      await t.pumpAndSettle();
      now = now.add(const Duration(seconds: 60));
      await t.tap(find.widgetWithText(TextButton, '恢复'));
      await t.pumpAndSettle();
      expect(p.journalEntries, isEmpty);
      expect(find.byTooltip('恢复'), findsNothing);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Editor keeps tags in input mode and keyboard backspace cleans leading lines with undo',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      await mount(
        t,
        p,
        JournalEditorPage(
          entry: note(
            '空行',
            document: [
              {'insert': '\n\n正文\n'},
            ],
          ),
        ),
      );
      expect(
        t
            .widgetList<JournalActionIcon>(find.byType(JournalActionIcon))
            .map((a) => a.symbol),
        [JournalActionSymbol.export, JournalActionSymbol.tags],
      );
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      editor.focusNode.requestFocus();
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.pump();
      expect(find.byTooltip('标签'), findsOneWidget);
      expect(
        t
            .widgetList<JournalActionIcon>(find.byType(JournalActionIcon))
            .map((a) => a.symbol),
        [
          JournalActionSymbol.undo,
          JournalActionSymbol.redo,
          JournalActionSymbol.tags,
          JournalActionSymbol.done,
        ],
      );
      final actionRects = find
          .byType(JournalActionIcon)
          .evaluate()
          .map((e) => t.getRect(find.byWidget(e.widget)))
          .toList();
      expect(actionRects.map((r) => r.top).toSet(), hasLength(1));
      expect(actionRects.map((r) => r.bottom).toSet(), hasLength(1));
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pump();
      expect(editor.controller.document.toPlainText(), '正文\n');
      await t.tap(find.byTooltip('撤回'));
      await t.pump();
      expect(editor.controller.document.toPlainText(), '\n\n正文\n');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets('Image metadata and tags are inside the exported boundary', (
    t,
  ) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await mount(t, p, JournalImagePage(entry: note('长图')));
    final metadata = find.byKey(const ValueKey('image-metadata'));
    expect(find.text('10月13日 10:30  |  2字'), findsOneWidget);
    final boundary = find
        .ancestor(of: metadata, matching: find.byType(RepaintBoundary))
        .first;
    expect(
      find.descendant(of: boundary, matching: find.text('灵感')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: boundary, matching: find.byType(quill.QuillEditor)),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets(
    'Ordered baseline follows actual first line and old checklists become bullets',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      await mount(
        t,
        p,
        JournalEditorPage(
          entry: note(
            '对齐',
            document: [
              {
                'insert': '首行较大并自动换行的正文内容测试文字',
                'attributes': {'size': '26'},
              },
              {
                'insert': '\n',
                'attributes': {'list': 'ordered'},
              },
              {
                'insert': '选框首行较大并自动换行的正文内容测试文字',
                'attributes': {'size': '26'},
              },
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
      final body = rich('首行较大并自动换行的正文内容测试文字');
      final marker = rich('1.');
      double baseline(Finder finder) {
        final render = t.renderObject<RenderParagraph>(finder);
        return render
            .localToGlobal(
              Offset(
                0,
                render.getDryBaseline(
                  render.constraints,
                  TextBaseline.alphabetic,
                )!,
              ),
            )
            .dy;
      }

      expect(baseline(marker), closeTo(baseline(body), .01));
      expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Repeated software keyboard newlines keep caret above the format bar',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      await mount(t, p, JournalEditorPage(entry: note('跟随光标')));
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      editor.focusNode.requestFocus();
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      for (var i = 0; i < 18; i++) {
        final text = '${'新行\n' * (i + 1)}\n';
        t.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length - 1),
          ),
        );
        await t.pump();
        await t.pump();
        final render = editor.config.editorKey!.currentState!.renderEditor;
        final caret = render.getLocalRectForCaret(
          editor.controller.selection.extent,
        );
        final bottom = render.localToGlobal(caret.bottomRight).dy;
        expect(
          bottom,
          lessThanOrEqualTo(t.getTopLeft(find.byType(JournalFormatBar)).dy - 8),
        );
      }
      expect(
        t
            .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('record-page-scroll')),
            )
            .controller!
            .offset,
        greaterThan(0),
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Collection dialogs fit narrow phone, focus name and show separate delete choices',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final setup = () async {
        await p.addJournalCollection('写作札记');
        await p.saveJournalEntry(
          note('秋日随记', folder: p.journalCollections.single.id),
        );
      }();
      await t.pumpAndSettle();
      await setup;
      final previews = Platform.environment['INCH_REVIEW_DIR'];
      if (previews != null) {
        await t.runAsync(() async {
          final bytes = await File(
            Platform.environment['INCH_REVIEW_FONT'] ??
                'C:/Windows/Fonts/msyh.ttc',
          ).readAsBytes();
          for (final family in ['Roboto', 'Microsoft YaHei', 'Ahem']) {
            final loader = FontLoader(family)
              ..addFont(Future.value(ByteData.sublistView(bytes)));
            await loader.load();
          }
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      await mount(t, p, const JournalPage());
      await t.longPress(find.text('写作札记'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(
              find.descendant(
                of: find.byType(JournalCollectionDialog),
                matching: find.byType(TextField),
              ),
            )
            .autofocus,
        true,
      );
      Future<void> capture(String name) async {
        if (previews == null) return;
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(previews).create(recursive: true);
          await File(
            '$previews/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('edit-collection');
      await t.tap(find.text('删除合集'));
      await t.pumpAndSettle();
      expect(find.byType(JournalDeleteCollectionDialog), findsOneWidget);
      expect(find.text('“写作札记” · 1 篇笔记'), findsOneWidget);
      await capture('delete-collection');
      await t.tap(find.text('保留笔记，删除合集'));
      await t.pumpAndSettle();
      expect(p.journalEntries.single.collectionId, isNull);
      expect(p.journalCollections, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
