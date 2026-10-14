import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/models/task_model.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_image_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/cycle_page.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/widgets/deadline_label.dart';
import 'package:inch_light/widgets/position_border.dart';
import 'package:inch_light/widgets/journal_body.dart';
import 'package:inch_light/widgets/swipe_delete_card.dart';
import 'package:inch_light/constants/app_colors.dart';

JournalEntry note(List<dynamic> ops) => JournalEntry(
  id: 'focus-note',
  title: '表格测试',
  document: ops,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Future<void> mount(WidgetTester t, AppProvider p, Widget page) async {
  t.view.physicalSize = const Size(390, 1000);
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

List<JournalTableData> tables(quill.QuillController c) => c.document
    .toDelta()
    .toJson()
    .where((op) => op['insert'] is Map)
    .map((op) => JournalTableData.decode(op['insert']['table'] as String))
    .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Format bar ignores hidden IME residual insets', (t) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await mount(t, p, const JournalEditorPage());
    addTearDown(t.view.resetViewInsets);
    await t.tap(find.byKey(const ValueKey('record-title')));
    for (final inset in [0.0, 1.0, 24.0]) {
      t.view.viewInsets = FakeViewPadding(bottom: inset);
      await t.pumpAndSettle();
      expect(find.byType(JournalFormatBar), findsNothing);
      expect(find.byTooltip('发送'), findsOneWidget);
    }
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await t.pumpAndSettle();
    expect(find.byType(JournalFormatBar), findsOneWidget);
    expect(find.byTooltip('确定'), findsOneWidget);
    t.view.viewInsets = const FakeViewPadding(bottom: 1);
    await t.pumpAndSettle();
    expect(find.byType(JournalFormatBar), findsNothing);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets(
    'Table cells and surrounding prose exclusively own focus and IME input, including composing and saved reload',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final table = JournalTableData.empty(3, 2);
      await mount(
        t,
        p,
        JournalEditorPage(
          entry: note([
            {'insert': '上文\n'},
            {
              'insert': {'table': table.encode()},
            },
            {'insert': '\n下文\n'},
          ]),
        ),
      );
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      final c = editor.controller;
      final cell = find.byKey(ValueKey('table-cell-${table.rows.last.id}-0'));
      final field = t.widget<TextField>(cell);
      Future<void> bodyAt(int offset) async {
        final render = editor.config.editorKey!.currentState!.renderEditor;
        final rect = render.getLocalRectForCaret(TextPosition(offset: offset));
        await t.tapAt(render.localToGlobal(rect.center + const Offset(2, 0)));
        await t.pumpAndSettle();
        expect(editor.focusNode.hasPrimaryFocus, true);
        expect(field.focusNode!.hasFocus, false);
      }

      for (final offset in [5, 0, 5]) {
        await t.tap(cell);
        await t.pumpAndSettle();
        expect(field.focusNode!.hasPrimaryFocus, true);
        expect(editor.focusNode.hasPrimaryFocus, false);
        expect(
          t
              .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
              .config
              .showCursor,
          false,
        );
        t.testTextInput.enterText('单元格');
        await t.pumpAndSettle();
        expect(tables(c).single.rows.last.cells.first, '单元格');
        expect(c.document.toPlainText(), '上文\n\uFFFC\n下文\n');
        await bodyAt(offset);
      }
      final state = t.testTextInput.editingState!;
      final text = state['text'] as String;
      final at = state['selectionBase'] as int;
      final input = text.replaceRange(at, at, '中文');
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: at + 2),
          composing: TextRange(start: at, end: at + 2),
        ),
      );
      await t.pump();
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: at + 2),
        ),
      );
      await t.pumpAndSettle();
      expect(c.document.toPlainText(), '上文\n\uFFFC\n中文下文\n');
      expect(tables(c).single.rows.last.cells.first, '单元格');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      final saved = p.journalEntries.single;
      expect(saved.document, c.document.toDelta().toJson());
      await t.pumpWidget(const SizedBox());
      await mount(t, p, JournalEditorPage(entry: saved));
      expect(
        t
            .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
            .controller
            .document
            .toDelta()
            .toJson(),
        saved.document,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Blank paragraph below an end table takes input from either last-row cell',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final data = JournalTableData.empty(3, 2);
      await mount(
        t,
        p,
        JournalEditorPage(
          entry: note([
            {
              'insert': {'table': data.encode()},
            },
            {'insert': '\n\n'},
          ]),
        ),
      );
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      for (final col in [0, 1]) {
        final cell = find.byKey(
          ValueKey('table-cell-${data.rows.last.id}-$col'),
        );
        await t.tap(cell);
        await t.pumpAndSettle();
        expect(t.widget<TextField>(cell).focusNode!.hasPrimaryFocus, true);
        final render = editor.config.editorKey!.currentState!.renderEditor;
        final caret = render.getLocalRectForCaret(
          const TextPosition(offset: 2),
        );
        await t.tapAt(render.localToGlobal(caret.center + const Offset(2, 0)));
        await t.pumpAndSettle();
        expect(editor.focusNode.hasPrimaryFocus, true);
        expect(t.widget<TextField>(cell).focusNode!.hasFocus, false);
      }
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '\uFFFC\n正文\n',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await t.pumpAndSettle();
      expect(editor.controller.document.toPlainText(), '\uFFFC\n正文\n');
      expect(tables(editor.controller).single.encode(), data.encode());
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  testWidgets(
    'Repeated backspace only deletes cell text and never removes table rows',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final table = JournalTableData.empty(3, 2).edit('unused', 0, '');
      final data = table
          .edit(table.rows[1].id, 0, 'ABCD')
          .edit(table.rows[1].id, 1, '另一格');
      await mount(
        t,
        p,
        JournalEditorPage(
          entry: note([
            {
              'insert': {'table': data.encode()},
            },
            {'insert': '\n后文\n'},
          ]),
        ),
      );
      final c = t
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      final cell = find.byKey(ValueKey('table-cell-${data.rows[1].id}-0'));
      await t.tap(cell);
      await t.pumpAndSettle();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ABC',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await t.pump(const Duration(milliseconds: 80));
      expect(tables(c).single.rows, hasLength(3));
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'AB',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await t.pumpAndSettle();
      expect(tables(c).single.rows, hasLength(3));
      expect(tables(c).single.rows[1].cells, ['AB', '另一格']);
      final empty = find.byKey(ValueKey('table-cell-${data.rows.last.id}-0'));
      await t.tap(empty);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pumpAndSettle();
      expect(tables(c).single.rows, hasLength(3));
      expect(c.document.toPlainText(), '\uFFFC\n后文\n');
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Deadline clear works in edit and create; collection positions have no special border and tags stay pale',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      p.addCollection('合集');
      p.addNormalTask(
        '待修改事项',
        collectionId: p.collections.single.id,
        deadline: DateTime(2030),
        tags: ['标签'],
      );
      p.normalTasks.single.isPinned = true;
      await mount(t, p, const TodoPage());
      final positioned = find.ancestor(
        of: find.text('待修改事项'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is ShapeDecoration &&
              (w.decoration! as ShapeDecoration).shape is PositionBorder,
        ),
      );
      expect(positioned, findsNothing);
      expect(
        t.widget<Text>(find.text('标签')).style!.color,
        const Color(0xFF9699A0),
      );
      final taskLabel = find.descendant(
        of: find.ancestor(
          of: find.text('待修改事项'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(DeadlineLabel),
      );
      expect(
        t.getTopLeft(taskLabel).dy - t.getBottomLeft(find.text('标签')).dy,
        greaterThanOrEqualTo(9),
      );
      await t.longPress(find.text('待修改事项'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('取消截止日期'));
      await t.pumpAndSettle();
      expect(find.text('设置截止时间'), findsOneWidget);
      await t.tap(find.text('保存修改'));
      await t.pumpAndSettle();
      expect(p.normalTasks.single.deadline, isNull);
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, '无截止事项');
      await t.tap(find.text('今日截止'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('取消截止日期'));
      await t.pumpAndSettle();
      await t.tap(find.text('完成'));
      await t.pumpAndSettle();
      expect(
        p.normalTasks.firstWhere((task) => task.title == '无截止事项').deadline,
        isNull,
      );
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Selected journal collection survives navigation and provider reload; missing folder falls back',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final setup = () async {
        await p.addJournalCollection('大学');
        await p.setLastModule('journal');
      }();
      await t.pumpAndSettle();
      await setup;
      await t.pumpWidget(
        ChangeNotifierProvider.value(value: p, child: const MyApp()),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('大学'));
      await t.pumpAndSettle();
      expect(p.lastJournalCollection, p.journalCollections.single.id);
      await t.tap(find.text('设置').last);
      await t.pumpAndSettle();
      await t.tap(find.text('记录').last);
      await t.pumpAndSettle();
      final selected = t.widget<Material>(
        find
            .ancestor(of: find.text('大学'), matching: find.byType(Material))
            .first,
      );
      expect(selected.color, const Color(0xFFE8EAED));
      await t.pumpWidget(const SizedBox());
      final restored = AppProvider();
      await t.runAsync(() => restored.ready);
      expect(restored.lastJournalCollection, p.journalCollections.single.id);
      final removing = restored.removeJournalCollection(
        restored.lastJournalCollection!,
      );
      await t.pumpAndSettle();
      await removing;
      expect(restored.lastJournalCollection, isNull);
      p.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'Countdown disappears at zero; near cards have red dots and keep pale borders',
    (t) async {
      var now = DateTime(2030, 1, 1, 12);
      final p = AppProvider(now: () => now);
      await t.runAsync(() => p.ready);
      p.addCountdown('刚到期', now);
      p.addCountdown('临近', now.add(const Duration(hours: 24)));
      p.addCountdown('更远', now.add(const Duration(hours: 25)));
      p.cycleTasks.add(
        CycleTask(
          id: 'cycle',
          title: '周期临近',
          frequency: CycleFrequency.daily,
          time: DateTime(2030, 1, 1, 18),
          nextRunTime: DateTime(2030, 1, 1, 18),
        ),
      );
      await mount(t, p, const CyclePage());
      Color border(String title) =>
          (t
                      .widget<Card>(
                        find.ancestor(
                          of: find.text(title),
                          matching: find.byType(Card),
                        ),
                      )
                      .shape!
                  as RoundedRectangleBorder)
              .side
              .color;
      expect(border('临近'), AppColors.divider);
      expect(border('周期临近'), AppColors.divider);
      expect(border('更远'), AppColors.divider);
      expect(
        find.byKey(ValueKey('completed-${p.countdowns.first.id}')),
        findsOneWidget,
      );
      await t.pump(const Duration(seconds: 1));
      expect(p.countdowns.any((c) => c.title == '刚到期'), false);
      now = now.add(const Duration(hours: 24));
      await t.pump(const Duration(seconds: 1));
      expect(p.countdowns.any((c) => c.title == '临近'), false);
      expect(p.cycleTasks.single.nextRunTime.isAfter(now), true);
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final restored = AppProvider(now: () => now);
        await restored.ready;
        expect(restored.countdowns.any((c) => c.title == '刚到期'), false);
        restored.dispose();
      });
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Image padding is 2.5em above and 3em below; H1 H2 margins exceed unchanged H3',
    (t) async {
      expect(journalStyles().h1!.verticalSpacing.top, 48);
      expect(journalStyles().h2!.verticalSpacing.top, 32);
      expect(journalStyles().h3!.verticalSpacing.top, 16);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      await mount(
        t,
        p,
        JournalImagePage(
          entry: note([
            {'insert': '内容\n'},
          ]),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Padding &&
              w.padding == const EdgeInsets.fromLTRB(24, 45, 24, 54),
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets(
    'Swipe underlay covers full rounded card instead of only exposed rectangle',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SwipeDeleteCard(
              id: 'item',
              onDeleted: _noop,
              child: SizedBox(
                width: 350,
                height: 100,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      );
      final gesture = await t.startGesture(
        t.getCenter(find.byType(Dismissible)),
      );
      await gesture.moveBy(const Offset(-80, 0));
      await t.pump();
      expect(
        t.getSize(find.byType(SwipeDeleteBackground)),
        t.getSize(find.byType(Dismissible)),
      );
      await gesture.cancel();
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'Note swipe follows finger, rebounds short drags and finishes its exit before deletion',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() async {
        await p.ready;
        await p.saveJournalEntry(
          note([
            {'insert': '内容\n'},
          ]),
        );
      });
      await mount(t, p, const JournalPage());
      final card = find.byKey(const ValueKey('note-card-focus-note'));
      final left = t.getTopLeft(card).dx;
      var gesture = await t.startGesture(t.getCenter(card));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-50, 0));
      await t.pump();
      expect(t.getTopLeft(card).dx, lessThan(left));
      expect(p.journalEntries, hasLength(1));
      await gesture.up();
      await t.pumpAndSettle();
      expect(t.getTopLeft(card).dx, left);
      gesture = await t.startGesture(t.getCenter(card));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-190, 0));
      await t.pump();
      final dragged = t.getTopLeft(card).dx;
      expect(p.journalEntries, hasLength(1));
      await gesture.up();
      await t.pump();
      await t.pump(const Duration(milliseconds: 70));
      expect(p.journalEntries, hasLength(1));
      expect(t.getTopLeft(card).dx, lessThan(dragged));
      await t.pumpAndSettle();
      expect(p.journalEntries, isEmpty);
      expect(p.recoverableJournalCount, 1);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}

void _noop() {}
