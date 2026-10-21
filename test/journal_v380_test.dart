import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_image_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/widgets/journal_table.dart';
import 'package:inch_light/widgets/journal_body.dart';
import 'package:inch_light/widgets/journal_image_settings.dart';

String plain(List<dynamic> ops) => quill.Document.fromJson(ops).toPlainText();
JournalEntry entry(List<dynamic> ops) => JournalEntry(
  id: 'note',
  title: 'vibe coding',
  document: ops,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  titleBold: true,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Space management trims each line and cell while preserving rich structure',
    () {
      const operation = JournalOperation.normalizeSpaces;
      for (final prefix in [' ', '\t', '　', '\u00a0', '\u0085', '\ufeff']) {
        expect(
          transformJournalText('$prefix标题\n${prefix}next line', operation),
          '标题\nnext line',
        );
      }
      var table = JournalTableData.empty(2, 2);
      for (final row in table.rows) {
        table = table
            .edit(row.id, 0, '　\t 单元格\n\u0085next  line')
            .edit(row.id, 1, '  表格hello  world');
      }
      final document = <dynamic>[
        {
          'insert': '　',
          'attributes': {'bold': true},
        },
        {
          'insert': '\u0085 \t',
          'attributes': {'italic': true},
        },
        {
          'insert': '标题',
          'attributes': {'underline': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {'insert': '  正文hello  world\n'},
        {'insert': '　列表项'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
        {'insert': ' \t　\n'},
        {'insert': '  '},
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n'},
      ];
      final original = document.toString();
      final result = transformJournalDocument(document, operation);
      expect(plain(result), '标题\n正文 hello world\n列表项\n\n\uFFFC\n');
      expect(result.first['attributes']['underline'], true);
      expect(result.any((op) => op['attributes']?['header'] == 2), true);
      expect(
        result.any(
          (op) =>
              op['attributes']?['list'] == 'bullet' &&
              op['attributes']?['indent'] == 1,
        ),
        true,
      );
      final cleanedTable = JournalTableData.decode(
        result.firstWhere((op) => op['insert'] is Map)['insert']['table'],
      );
      expect(cleanedTable.id, table.id);
      expect(
        cleanedTable.rows.map((row) => row.id),
        table.rows.map((row) => row.id),
      );
      expect(
        cleanedTable.rows.map((row) => row.cells),
        everyElement(['单元格\nnext line', '表格 hello world']),
      );
      expect(document.toString(), original);
      expect(transformJournalDocument(result, operation), result);
    },
  );

  test(
    'Leading punctuation cleans title, paragraphs, lists and table cells while preserving quotes and styles',
    () {
      const op = JournalOperation.removeLeadingPunctuation;
      expect(transformJournalText('  ，。？！标题，正文。', op), '  标题，正文。');
      for (final prefix in [
        '“',
        '”',
        '‘',
        '’',
        '「',
        '」',
        '『',
        '』',
        '《',
        '》',
        '〈',
        '〉',
        '（',
        '）',
        '【',
        '】',
        '[',
        ']',
        '{',
        '}',
        '"',
        "'",
        '«',
        '»',
      ]) {
        expect(
          transformJournalText(
            '？！$prefix'
            '内容。',
            op,
          ),
          '$prefix'
          '内容。',
        );
      }
      var table = JournalTableData.empty(1, 1);
      table = table.edit(table.rows.first.id, 0, '，单元格\n！下一段');
      final result = transformJournalDocument([
        {
          'insert': '，',
          'attributes': {'bold': true},
        },
        {
          'insert': '。正文，保留。',
          'attributes': {'italic': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {'insert': '？！列表'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered', 'indent': 1},
        },
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n'},
      ], op);
      expect(plain(result), startsWith('正文，保留。\n列表。\n'));
      expect(result.first['attributes']['italic'], true);
      expect(result.any((a) => a['attributes']?['header'] == 2), true);
      expect(
        result.any(
          (a) =>
              a['attributes']?['list'] == 'ordered' &&
              a['attributes']?['indent'] == 1,
        ),
        true,
      );
      final updated = JournalTableData.decode(
        result.firstWhere((a) => a['insert'] is Map)['insert']['table'],
      );
      expect(updated.id, table.id);
      expect(updated.plainText, '单元格\n下一段');
      expect(transformJournalText('？！', op), '');
      expect(transformJournalText('😀测试！', op), '😀测试！');
    },
  );
  test(
    'Whole-note transformations preserve spans, embeds, Unicode and heading limits',
    () {
      final table = JournalTableData.empty(1, 1).edit('missing', 0, '');
      final ops = [
        {
          'insert': 'har',
          'attributes': {'bold': true},
        },
        {
          'insert': 'ness vibe coding deepseek😀\n',
          'attributes': {'italic': true},
        },
        {'insert': '  \n'},
        {'insert': '一'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {'insert': '二'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {'insert': '三'},
        {
          'insert': '\n',
          'attributes': {'header': 3},
        },
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n'},
      ];
      final original = ops.toString();
      final capital = transformJournalDocument(
        ops,
        JournalOperation.capitalize,
      );
      expect(plain(capital), startsWith('Harness Vibe Coding Deepseek😀\n'));
      expect(capital.first['attributes']['bold'], true);
      final noBold = transformJournalDocument(ops, JournalOperation.removeBold);
      expect(noBold.where((op) => op['attributes']?['bold'] == true), isEmpty);
      expect(plain(noBold), plain(ops));
      expect(noBold.any((op) => op['attributes']?['italic'] == true), true);
      final noBlank = transformJournalDocument(
        ops,
        JournalOperation.clearBlankLines,
      );
      expect(plain(noBlank).contains('  \n'), false);
      expect(noBlank.any((op) => op['insert'] is Map), true);
      expect(
        plain(
          transformJournalDocument([
            {'insert': ' \n\n'},
          ], JournalOperation.clearBlankLines),
        ),
        '\n',
      );
      for (final (action, expected) in [
        (JournalOperation.promoteHeadings, [1, 1, 2]),
        (JournalOperation.demoteHeadings, [2, 3, 3]),
      ]) {
        final result = transformJournalDocument(ops, action);
        expect(
          result
              .where((op) => op['attributes']?['header'] != null)
              .map((op) => op['attributes']['header']),
          expected,
        );
      }
      expect(ops.toString(), original);
    },
  );

  test(
    'Spacing crosses formatting boundaries and handles English punctuation and table cells',
    () {
      var table = JournalTableData.empty(1, 1);
      table = table.edit(table.rows.first.id, 0, '中文hello  world中文');
      final result = transformJournalDocument([
        {
          'insert': ' 汉 字har',
          'attributes': {'bold': true},
        },
        {'insert': 'ness   vibe coding中文， hello ,  world!  😀 \n'},
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n'},
      ], JournalOperation.normalizeSpaces);
      expect(
        plain(result),
        startsWith('汉字 harness vibe coding 中文，hello, world!😀\n'),
      );
      expect(
        JournalTableData.decode(
          result.firstWhere((op) => op['insert'] is Map)['insert']['table'],
        ).plainText,
        '中文 hello world 中文',
      );
      expect(result.first['attributes']['bold'], true);
    },
  );

  test(
    'Each bullet list shuffles independently and keeps descendants with their parent',
    () {
      final ops = <dynamic>[];
      void line(String text, {bool bullet = true, int indent = 0}) {
        ops.add({
          'insert': text,
          'attributes': {'italic': true},
        });
        ops.add({
          'insert': '\n',
          if (bullet)
            'attributes': {'list': 'bullet', if (indent > 0) 'indent': indent},
        });
      }

      line('A');
      line('A1', indent: 1);
      line('A2', indent: 1);
      line('B');
      line('分隔', bullet: false);
      line('X');
      line('Y');
      line('结束', bullet: false);
      final shuffled = plain(
        transformJournalDocument(
          ops,
          JournalOperation.shuffleBullets,
          random: Random(7),
        ),
      ).trim().split('\n');
      final split = shuffled.indexOf('分隔');
      expect(shuffled.take(split).toSet(), {'A', 'A1', 'A2', 'B'});
      expect(shuffled.skip(split + 1).take(2).toSet(), {'X', 'Y'});
      expect(
        shuffled
            .sublist(shuffled.indexOf('A') + 1, shuffled.indexOf('A') + 3)
            .toSet(),
        {'A1', 'A2'},
      );
      expect(shuffled.last, '结束');
    },
  );

  test(
    'Table row deletion and right insertion preserve identity and rectangular data',
    () {
      var table = JournalTableData.empty(3, 2);
      final ids = table.rows.map((r) => r.id).toList();
      for (var r = 0; r < 3; r++) {
        table = table.edit(ids[r], 0, '$r左').edit(ids[r], 1, '$r右');
      }
      final inserted = table.insertColumnAfter(0);
      expect(inserted.id, table.id);
      expect(inserted.columns, 3);
      expect(inserted.rows[1].cells, ['1左', '', '1右']);
      final removedColumn = inserted.removeColumn(0);
      expect(removedColumn.rows[1].cells, ['', '1右']);
      expect(removedColumn.id, table.id);
      expect(JournalTableData.decode(removedColumn.encode()).columns, 2);
      final deleted = inserted.removeRow(ids[1]);
      expect(deleted.rows.map((r) => r.id), [ids[0], ids[2]]);
      expect(JournalTableData.decode(deleted.encode()).rows.last.cells, [
        '2左',
        '',
        '2右',
      ]);
      expect(JournalTableData.empty(1, 12).insertColumnAfter(4).columns, 12);
      final single = JournalTableData.empty(1, 2);
      expect(
        JournalTableData.decode(
          single.removeRow(single.rows.first.id).encode(),
        ).rows,
        hasLength(1),
      );
    },
  );

  test(
    'First column keeps four Han characters while other columns still lend spare width',
    () {
      var table = JournalTableData.empty(2, 2);
      table = table.edit(table.rows.first.id, 1, '汉' * 40);
      final widths = journalTableWidths(table, 360, TextScaler.noScaling);
      expect(widths.first, closeTo(90, .01));
      expect(widths.reduce((a, b) => a + b), closeTo(360, .01));
      table = JournalTableData.empty(2, 2).edit(table.rows.first.id, 0, '');
      table = table.edit(table.rows.first.id, 0, '汉' * 40);
      expect(
        journalTableWidths(table, 360, TextScaler.noScaling)[1],
        closeTo(34.5, .01),
      );
    },
  );

  testWidgets(
    'Table long press exposes row actions and dynamically adds a column',
    (t) async {
      var table = JournalTableData.empty(2, 2);
      final row = table.rows.last.id;
      table = table.edit(row, 0, '测试');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalTable(data: table, onChanged: (next) => table = next),
          ),
        ),
      );
      final cell = find.byKey(ValueKey('table-cell-$row-0'));
      await t.tap(cell);
      await t.pumpAndSettle();
      await t.longPress(cell);
      await t.pumpAndSettle();
      expect(find.text('删除该行'), findsOneWidget);
      await t.tap(find.text('右侧增列'));
      await t.pumpAndSettle();
      expect(table.columns, 3);
      expect(find.byType(TextField), findsNWidgets(6));
      await t.longPress(cell);
      await t.pumpAndSettle();
      await t.tap(find.text('删除该列'));
      await t.pumpAndSettle();
      expect(table.columns, 2);
      expect(table.rows.last.cells, ['', '']);
      expect(find.byType(TextField), findsNWidgets(4));
      await t.longPress(cell);
      await t.pumpAndSettle();
      await t.tap(find.text('删除该行'));
      await t.pumpAndSettle();
      expect(table.rows, hasLength(1));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Partial display supports bulk selection and persists without section folding',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      p.addCollection('甲');
      p.addCollection('乙');
      final a = p.collections.firstWhere((c) => c.title == '甲');
      final b = p.collections.firstWhere((c) => c.title == '乙');
      p.addNormalTask('甲事项', collectionId: a.id);
      p.addNormalTask('乙事项', collectionId: b.id);
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(home: TodoPage()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('折叠'), findsNothing);
      await t.tap(find.byTooltip('部分显示'));
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('部分显示')).dx,
        t
            .getTopLeft(
              find.descendant(
                of: find.widgetWithText(CheckboxListTile, '甲'),
                matching: find.text('甲'),
              ),
            )
            .dx,
      );
      await t.tap(find.widgetWithText(CheckboxListTile, '甲'));
      await t.tap(find.text('确定'));
      await t.pumpAndSettle();
      expect(find.text('甲'), findsNothing);
      expect(find.text('甲事项'), findsNothing);
      expect(find.text('乙事项'), findsOneWidget);
      await t.drag(find.text('乙'), const Offset(650, 0));
      await t.pumpAndSettle();
      expect(find.text('已取消显示'), findsOneWidget);
      expect(find.text('乙'), findsNothing);
      expect(p.collections.any((c) => c.id == b.id), true);
      expect(p.isTodoCollectionVisible(b.id), false);
      await t.tap(find.byTooltip('部分显示'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '乙'),
            )
            .value,
        false,
      );
      await t.tap(find.widgetWithText(CheckboxListTile, '乙'));
      await t.tap(find.text('确定'));
      await t.pumpAndSettle();
      expect(find.text('乙事项'), findsOneWidget);
      await t.tap(find.byTooltip('部分显示'));
      await t.pumpAndSettle();
      await t.tap(find.text('全选'));
      await t.pump();
      expect(
        t
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((w) => w.value == true),
        true,
      );
      await t.tap(find.text('全不选'));
      await t.pump();
      expect(
        t
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((w) => w.value == false),
        true,
      );
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      final reloaded = AppProvider();
      await t.runAsync(() => reloaded.ready);
      expect(reloaded.isTodoCollectionVisible(a.id), false);
      expect(reloaded.isTodoCollectionVisible(b.id), true);
      reloaded.dispose();
      p.dispose();
    },
  );

  testWidgets('Toolbar order, multi-select, whole-note operation and undo', (
    t,
  ) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    final note = entry([
      {'insert': 'harness deepseek\n'},
    ]);
    await t.runAsync(() => p.saveJournalEntry(note));
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: JournalPage()),
      ),
    );
    await t.pumpAndSettle();
    final tools = [
      '批量导出 Markdown',
      '新建合集',
      '多选',
    ].map((label) => t.getRect(find.byTooltip(label))).toList();
    expect(tools[0].center.dx, lessThan(tools[1].center.dx));
    expect(tools[1].center.dx, lessThan(tools[2].center.dx));
    expect(tools.map((r) => r.height).toSet(), hasLength(1));
    expect(tools.map((r) => r.center.dy).toSet(), hasLength(1));
    await t.tap(find.byTooltip('多选'));
    await t.pumpAndSettle();
    expect(find.text('已选 0 项'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(home: JournalEditorPage(entry: note)),
      ),
    );
    await t.pumpAndSettle();
    final actions = [
      '导出',
      '标签',
      '操作',
    ].map((label) => t.getRect(find.byTooltip(label))).toList();
    expect(actions[0].center.dx, lessThan(actions[1].center.dx));
    expect(actions[1].center.dx, lessThan(actions[2].center.dx));
    expect(actions.map((r) => r.height).toSet(), hasLength(1));
    expect(actions.map((r) => r.center.dy).toSet(), hasLength(1));
    await t.tap(find.byTooltip('操作'));
    await t.pumpAndSettle();
    expect(
      t
          .widgetList<PopupMenuItem<JournalOperation>>(
            find.byType(PopupMenuItem<JournalOperation>),
          )
          .where((item) => item.value != null)
          .map((item) => item.value!.label),
      ['标点管理', '空格管理', '清除空行', '打乱无序列表', '标题升级', '标题降级', '取消加粗', '首字母大写'],
    );
    await t.tap(find.text('首字母大写'));
    await t.pumpAndSettle();
    final editor = t.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    expect(editor.controller.document.toPlainText(), 'Harness Deepseek\n');
    expect(editor.focusNode.hasFocus, false);
    expect(t.testTextInput.isVisible, false);
    await t.tap(find.text('撤回'));
    await t.pumpAndSettle();
    expect(editor.controller.document.toPlainText(), 'harness deepseek\n');
    expect(editor.focusNode.hasFocus, false);
    expect(t.testTextInput.isVisible, false);
    await t.tap(find.byTooltip('操作'));
    await t.pumpAndSettle();
    await t.tap(find.text('首字母大写'));
    await t.pumpAndSettle();
    expect(find.text('已首字母大写'), findsOneWidget);
    expect(t.widget<SnackBar>(find.byType(SnackBar)).persist, false);
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('Image settings rebuild preview and preserve the original note', (
    t,
  ) async {
    t.view.physicalSize = const Size(500, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final note = entry([
      {'insert': '正文\n另一段\n'},
    ]);
    final before = note.document.toString();
    await t.pumpWidget(MaterialApp(home: JournalImagePage(entry: note)));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('图片设置'));
    await t.pumpAndSettle();
    final slider = t.widget<Slider>(find.byKey(const ValueKey('image-字号')));
    slider.onChanged!(24);
    t.widget<Slider>(find.byKey(const ValueKey('image-顶部留白'))).onChanged!(72);
    t.widget<Slider>(find.byKey(const ValueKey('image-底部留白'))).onChanged!(80);
    t.widget<Slider>(find.byKey(const ValueKey('image-两侧留白'))).onChanged!(36);
    await t.ensureVisible(find.text('开头空两格'));
    await t.tap(find.text('开头空两格'));
    await t.ensureVisible(find.text('隐藏编辑时间与字数'));
    await t.tap(find.text('隐藏编辑时间与字数'));
    await t.tap(find.text('完成'));
    await t.pumpAndSettle();
    expect(find.byType(JournalImageSettingsDialog), findsNothing);
    expect(find.byKey(const ValueKey('image-metadata')), findsNothing);
    final editor = t.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    expect(editor.config.customStyles!.paragraph!.style.fontSize, 24);
    expect(
      t
          .widget<Padding>(find.byKey(const ValueKey('image-page-padding')))
          .padding,
      const EdgeInsets.fromLTRB(36, 72, 36, 80),
    );
    expect(editor.controller.document.toPlainText(), '　　正文\n　　另一段\n');
    expect(note.document.toString(), before);
    await t.tap(find.byTooltip('图片设置'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('开头空两格'));
    await t.tap(find.text('开头空两格'));
    await t.tap(find.text('完成'));
    await t.pumpAndSettle();
    expect(editor.controller.document.toPlainText(), '正文\n另一段\n');
  });

  testWidgets(
    'Remove bold preserves heading weight and clears table header bold after reload',
    (t) async {
      final table = JournalTableData.empty(1, 1);
      final ops = transformJournalDocument([
        {
          'insert': '标题',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {
          'insert': {'table': table.encode()},
        },
        {'insert': '\n'},
      ], JournalOperation.removeBold);
      final doc = quill.Document.fromJson(ops);
      late BuildContext context;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final line = doc.root.children.first as quill.Line;
      final span =
          journalSpan(
                context,
                line.children.first,
                0,
                '标题',
                journalStyles().h1!.style,
                null,
              )
              as TextSpan;
      expect(span.style!.fontWeight, FontWeight.w700);
      final decoded = JournalTableData.decode(
        ops.firstWhere((op) => op['insert'] is Map)['insert']['table'],
      );
      expect(decoded.headerBold, false);
      expect(
        decoded
            .insertColumnAfter(0)
            .insertAfter(decoded.rows.first.id)
            .headerBold,
        false,
      );
      doc.close();
    },
  );

  testWidgets('App overlay uses Chinese selection commands', (t) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await t.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const MyApp()),
    );
    await t.pumpAndSettle();
    final context = t.element(find.byType(Navigator));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JournalEditorPage(
          entry: entry([
            {'insert': '正文\n'},
          ]),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.longPressAt(
      t.getTopLeft(find.byType(TextField).first) + const Offset(30, 20),
    );
    await t.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(
      MaterialLocalizations.of(
        t.element(find.byType(TextField).first),
      ).pasteButtonLabel,
      '粘贴',
    );
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('Settings exposes current version and Symplatt copyright', (
    t,
  ) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await t.tap(find.byTooltip('软件信息'));
    await t.pumpAndSettle();
    expect(find.text('软件信息'), findsNothing);
    expect(find.text('一日千录'), findsOneWidget);
    expect(find.text('版本 3.12.2（构建 63）'), findsOneWidget);
    expect(find.text('版权所有 © Symplatt'), findsOneWidget);
    final lefts = [
      '一日千录',
      '版本 3.12.2（构建 63）',
      '版权所有 © Symplatt',
      '数据保存在本机，可在设置中导出备份。',
    ].map((text) => t.getTopLeft(find.text(text)).dx).toSet();
    expect(lefts, hasLength(1));
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
