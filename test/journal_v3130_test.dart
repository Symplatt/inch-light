import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_quill/src/editor/widgets/proxy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/widgets/journal_chain_dialog.dart';

JournalEntry note(
  String title,
  List<dynamic> document, {
  bool pinned = false,
  bool bottom = false,
}) => JournalEntry(
  id: title,
  title: title,
  document: document,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isPinned: pinned,
  isBottom: bottom,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Name sorting preserves pin and bottom priority and survives restart',
    () async {
      final p = AppProvider();
      await p.ready;
      addTearDown(p.dispose);
      for (final name in ['周记', 'apple', '北京', 'Zoo', '安宁']) {
        await p.addJournalCollection(name);
        await p.saveJournalEntry(
          note(name, [
            {'insert': '正文\n'},
          ]),
        );
      }
      await p.saveJournalEntry(
        note('置顶', [
          {'insert': '正文\n'},
        ], pinned: true),
      );
      await p.saveJournalEntry(
        note('aaa', [
          {'insert': '正文\n'},
        ], bottom: true),
      );
      await p.setJournalSort(JournalSort.name, collections: true);
      await p.setJournalSort(JournalSort.name, collections: false);
      expect(p.journalCollections.map((c) => c.title), [
        'apple',
        'Zoo',
        '安宁',
        '北京',
        '周记',
      ]);
      expect(p.journalEntries.map((e) => e.title), [
        '置顶',
        'apple',
        'Zoo',
        '安宁',
        '北京',
        '周记',
        'aaa',
      ]);
      final restarted = AppProvider();
      await restarted.ready;
      addTearDown(restarted.dispose);
      expect(restarted.journalCollectionSort, JournalSort.name);
      expect(restarted.journalEntrySort, JournalSort.name);
      expect(
        restarted.journalEntries.map((e) => e.title),
        p.journalEntries.map((e) => e.title),
      );
    },
  );

  test('Space management preserves H1 H2 H3 and their inline attributes', () {
    for (final level in [1, 2, 3]) {
      final source = <dynamic>[
        {
          'insert': '  中文 English  标题 ',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': level},
        },
        {'insert': '  正文hello  world\n'},
      ];
      final result = transformJournalDocument(
        source,
        JournalOperation.normalizeSpaces,
      );
      expect(result.take(2), source.take(2));
      expect(
        q.Document.fromJson(result).toPlainText(),
        '  中文 English  标题 \n正文 hello world\n',
      );
    }
  });

  test(
    'Operation visibility follows content, including headings at either limit',
    () {
      const always = {
        JournalOperation.removeLeadingPunctuation,
        JournalOperation.normalizeSpaces,
      };
      expect(
        availableJournalOperations([
          {'insert': '正文\n'},
        ]),
        always,
      );
      for (final header in [1, 2, 3]) {
        final available = availableJournalOperations([
          {'insert': '标题'},
          {
            'insert': '\n',
            'attributes': {'header': header},
          },
        ]);
        expect(
          available,
          containsAll([
            JournalOperation.promoteHeadings,
            JournalOperation.demoteHeadings,
          ]),
        );
      }
      var table = JournalTableData.empty(1, 1);
      table = table.edit(table.rows.first.id, 0, 'letters');
      final available = availableJournalOperations([
        {
          'insert': '正文',
          'attributes': {'bold': true},
        },
        {'insert': '\n\n'},
        {'insert': '条目'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': '待办'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n'},
      ]);
      expect(
        available,
        containsAll([
          JournalOperation.removeBold,
          JournalOperation.capitalize,
          JournalOperation.clearBlankLines,
          JournalOperation.shuffleBullets,
          JournalOperation.checkAll,
          JournalOperation.uncheckAll,
        ]),
      );
      expect(
        availableJournalOperations(
          [
            {'insert': '正文\n'},
          ],
          title: 'ABC',
          titleBold: true,
        ),
        containsAll([JournalOperation.capitalize, JournalOperation.removeBold]),
      );
    },
  );

  test(
    'Checkbox batch operations persist and export without losing inline styles',
    () {
      final source = <dynamic>[
        {
          'insert': '第一项',
          'attributes': {'italic': true},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
        {'insert': '第二项'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
        {'insert': '普通项'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ];
      final checked = transformJournalDocument(
        source,
        JournalOperation.checkAll,
      );
      expect(
        checked.where((op) => op['attributes']?['list'] == 'checked'),
        hasLength(2),
      );
      expect(checked.first['attributes']['italic'], true);
      expect(checked.last['attributes']['list'], 'bullet');
      final restored = JournalEntry.fromJson(note('选框', checked).toJson());
      expect(restored.document, checked);
      expect(journalToMarkdown(restored), contains('- [x] *第一项*\n- [x] 第二项'));
      final unchecked = transformJournalDocument(
        checked,
        JournalOperation.uncheckAll,
      );
      expect(
        unchecked.where((op) => op['attributes']?['list'] == 'unchecked'),
        hasLength(2),
      );
      expect(
        transformJournalDocument(unchecked, JournalOperation.uncheckAll),
        unchecked,
      );
    },
  );

  for (final kind in ['ordered', 'bullet', 'checked', 'unchecked']) {
    for (final position in ['first', 'middle', 'last', 'single']) {
      test(
        'Blank $kind $position list item deletes without merging prose styles',
        () {
          final document = <dynamic>[
            if (position != 'first' && position != 'single') ...[
              {'insert': '前项'},
              {
                'insert': '\n',
                'attributes': {'list': kind},
              },
            ],
            {
              'insert': '\n',
              'attributes': {'list': kind},
            },
            if (position != 'last' && position != 'single') ...[
              {
                'insert': '后项',
                'attributes': {'bold': true},
              },
              {
                'insert': '\n',
                'attributes': {'list': kind},
              },
            ],
          ];
          final at = position == 'middle' || position == 'last' ? 3 : 0;
          final c = JournalController(
            document: q.Document.fromJson(document),
            selection: TextSelection.collapsed(offset: at),
          );
          addTearDown(c.dispose);
          // Exercise the IME replacement path where possible and the explicit
          // backspace callback at offset zero, where no replacement can be sent.
          if (at > 0) {
            c.replaceText(
              at - 1,
              1,
              '',
              TextSelection.collapsed(offset: at - 1),
            );
          } else {
            c.onDelete!(at, false);
          }
          expect(c.selection.baseOffset, at);
          if (position == 'middle') {
            expect(c.document.toPlainText(), '前项\n后项\n');
            expect(
              c.document.toDelta().toJson().where(
                (op) => op['attributes']?['list'] == kind,
              ),
              hasLength(2),
            );
          } else {
            final line = c.document.queryChild(at).node! as q.Line;
            expect(line.toPlainText(), '\n');
            expect(line.toDelta().last.attributes?['list'], isNull);
            expect(
              c.document.toPlainText(),
              q.Document.fromJson(document).toPlainText(),
            );
          }
          c.replaceText(at, 0, '新', TextSelection.collapsed(offset: at + 1));
          expect(c.document.toPlainText(), contains('新'));
        },
      );
    }
  }

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'Checklist spacing stays at unchecked geometry across mixed states at $scale',
      (t) async {
        t.view.physicalSize = const Size(420, 1200);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final p = AppProvider();
        await t.runAsync(() => p.ready);
        final labels = ['第一项自动换行的测试内容，保证多行条目的间距也不受勾选状态影响', '第二项', '第三项'];
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: p,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: JournalEditorPage(
                entry: note('间距', [
                  {'insert': '列表前正文\n'},
                  for (final label in labels) ...[
                    {'insert': label},
                    {
                      'insert': '\n',
                      'attributes': {'list': 'unchecked'},
                    },
                  ],
                  {'insert': '列表后正文\n'},
                ]),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        Finder rich(String text) => find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == text,
        );
        List<Rect> bounds() => [
          ...labels,
          '列表后正文',
        ].map((label) => t.getRect(rich(label))).toList();
        final unchecked = bounds();
        for (final action in [
          (1, true),
          (0, true),
          (2, true),
          (1, false),
          (0, false),
          (2, false),
        ]) {
          t
              .widgetList<Checkbox>(find.byType(Checkbox))
              .elementAt(action.$1)
              .onChanged!(action.$2);
          await t.pumpAndSettle();
          final actual = bounds();
          for (var i = 0; i < unchecked.length; i++) {
            expect(actual[i].top, closeTo(unchecked[i].top, .01));
            expect(actual[i].height, closeTo(unchecked[i].height, .01));
          }
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        p.dispose();
      },
    );
  }

  testWidgets('Inline-code button removes the full contiguous styled span', (
    t,
  ) async {
    final c = JournalController(
      document: q.Document.fromJson([
        {'insert': '前'},
        {
          'insert': 'ab',
          'attributes': {'code': true},
        },
        {
          'insert': 'cd',
          'attributes': {'code': true, 'bold': true},
        },
        {'insert': '后\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 3),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalFormatBar(
            controller: c,
            onFormat: () {},
            onTable: () {},
          ),
        ),
      ),
    );
    t
        .widget<IconButton>(find.byKey(const ValueKey('format-行内代码')))
        .onPressed!();
    await t.pump();
    expect(c.document.toPlainText(), '前abcd后\n');
    expect(
      c.document.toDelta().toJson().any(
        (op) => op['attributes']?['code'] == true,
      ),
      false,
    );
    expect(
      c.document.toDelta().toJson().any(
        (op) => op['attributes']?['bold'] == true,
      ),
      true,
    );
    expect(c.selection.baseOffset, 3);
    c.replaceText(3, 0, 'x', const TextSelection.collapsed(offset: 4));
    expect(
      c.document.toDelta().toJson().any(
        (op) => op['attributes']?['code'] == true,
      ),
      false,
    );
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('Real settings and editor rendering and content-aware menu', (
    t,
  ) async {
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final output = Platform.environment['INCH_REVIEW_DIR'];
    if (output != null) {
      for (final (family, path) in [
        ('ReviewSans', 'C:/Windows/Fonts/msyh.ttc'),
        (
          'MaterialIcons',
          'C:/Users/CJZ/.cache/inch-light-tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ]) {
        final loader = FontLoader(family)
          ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
        await t.runAsync(loader.load);
      }
    }
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    final capture = GlobalKey();
    Future<void> mount(Widget page) async {
      await t.pumpWidget(const SizedBox());
      final original =
          const MyApp().build(t.element(find.byType(SizedBox))) as MaterialApp;
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: output == null
                ? original.theme
                : original.theme!.copyWith(
                    textTheme: original.theme!.textTheme.apply(
                      fontFamily: 'ReviewSans',
                    ),
                  ),
            localizationsDelegates: original.localizationsDelegates,
            supportedLocales: original.supportedLocales,
            locale: original.locale,
            builder: (context, child) =>
                RepaintBoundary(key: capture, child: child!),
            home: page,
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> screenshot(String name) async {
      if (output == null) return;
      await t.runAsync(() async {
        final box =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await box.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File(
          '$output/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await mount(const SettingsPage());
    expect(
      t.getTopLeft(find.text('记录排序')).dy,
      lessThan(t.getTopLeft(find.text('时历顺序')).dy),
    );
    final todoFirst = t.getTopLeft(
      find.byKey(const ValueKey('todo-order-collections')),
    );
    final todoSecond = t.getTopLeft(
      find.byKey(const ValueKey('todo-order-loose')),
    );
    expect(todoFirst.dx, todoSecond.dx);
    expect(todoSecond.dy - todoFirst.dy, 44);
    final calendarFirst = t.getTopLeft(
      find.byKey(const ValueKey('calendar-order-countdowns')),
    );
    final calendarSecond = t.getTopLeft(
      find.byKey(const ValueKey('calendar-order-cycles')),
    );
    expect(calendarFirst.dx, todoFirst.dx);
    expect(calendarSecond.dy - calendarFirst.dy, 44);
    await t.ensureVisible(find.text('记录排序'));
    await t.pumpAndSettle();
    for (final group in ['collections', 'entries']) {
      final circle = find.byKey(ValueKey('journal-sort-circle-$group-edited'));
      final title = find.byKey(ValueKey('journal-sort-title-$group'));
      expect(t.getTopLeft(circle).dx, t.getTopLeft(title).dx);
      expect(
        t.getTopLeft(title).dx,
        t.getTopLeft(find.byKey(const ValueKey('journal-sort-card'))).dx + 20,
      );
    }
    await t.tap(find.text('名称').last);
    await t.pumpAndSettle();
    expect(p.journalEntrySort, JournalSort.name);
    await screenshot('settings');
    final doc = <dynamic>[
      {'insert': '资料整理'},
      {
        'insert': '\n',
        'attributes': {'header': 2},
      },
      {'insert': '整理会议记录并核对全部附件，补充遗漏的事项和后续处理安排'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': '完成资料归档'},
      {
        'insert': '\n',
        'attributes': {'list': 'checked'},
      },
      {'insert': '核对版本信息'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {
        'insert': 'flutter analyze',
        'attributes': {'code': true},
      },
      {'insert': '\n'},
      {'insert': '检查完成后记录结果。\n'},
    ];
    await mount(JournalEditorPage(entry: note('本周事项', doc)));
    final proxy = t.renderObject<RenderParagraphProxy>(
      find
          .byWidgetPredicate(
            (w) => w is RichTextProxy && w.inlineCodeOffsets.padding.isNotEmpty,
          )
          .last,
    );
    expect(
      proxy.inlineCodeOffsets.padding.where((pad) => pad.leading),
      hasLength(1),
    );
    final caret = proxy.getOffsetForCaret(
      const TextPosition(offset: 0),
      Rect.zero,
    );
    expect(caret.dx, closeTo(10.5, .1));
    final codeText = proxy.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 14),
    );
    expect(codeText.first.left, closeTo(10.5, .1));
    await screenshot('editor');
    final boxes = t.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(boxes, hasLength(3));
    final editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
    boxes.first.onChanged!(true);
    await t.pumpAndSettle();
    expect(
      editor.controller.document.toDelta().toJson().where(
        (op) => op['attributes']?['list'] == 'checked',
      ),
      hasLength(2),
    );
    await t.tap(find.byTooltip('操作'));
    await t.pumpAndSettle();
    expect(find.text('选框操作'), findsOneWidget);
    expect(find.byIcon(Icons.indeterminate_check_box_outlined), findsOneWidget);
    expect(find.text('打乱无序列表'), findsNothing);
    await screenshot('menu');
    await t.tap(find.text('勾选全部'));
    await t.pumpAndSettle();
    expect(
      editor.controller.document.toDelta().toJson().where(
        (op) => op['attributes']?['list'] == 'checked',
      ),
      hasLength(3),
    );
    await mount(
      JournalEditorPage(
        entry: note('  标题 English  ', [
          {'insert': '  正文hello\n'},
        ]),
      ),
    );
    await t.tap(find.byTooltip('操作'));
    await t.pumpAndSettle();
    await t.tap(find.text('空格管理'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('record-title')))
          .controller!
          .text,
      '  标题 English  ',
    );
    await mount(
      JournalEditorPage(
        entry: note('会议记录', [
          {'insert': '普通正文\n'},
        ]),
      ),
    );
    await t.tap(find.byTooltip('操作'));
    await t.pumpAndSettle();
    expect(find.text('格式调整'), findsNothing);
    expect(find.text('选框操作'), findsNothing);
    expect(find.text('清除空行'), findsNothing);
    await screenshot('menu-minimal');
    await t.tap(find.byTooltip('编辑连携操作'));
    await t.pumpAndSettle();
    expect(find.byType(JournalChainDialog), findsOneWidget);
    expect(find.text('勾选全部'), findsOneWidget);
    expect(find.text('清空勾选'), findsOneWidget);
    expect(find.text('标题升级'), findsOneWidget);
    await screenshot('chain');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
