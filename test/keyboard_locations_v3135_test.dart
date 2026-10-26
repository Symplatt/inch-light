import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/screens/cycle_page.dart';
import 'package:inch_light/widgets/journal_collection_dialog.dart';
import 'package:inch_light/widgets/journal_table.dart';
import 'package:inch_light/widgets/date_time_sheet.dart';
import 'package:inch_light/widgets/app_dialog.dart';
import 'package:inch_light/models/journal_table.dart';
import 'journal_v3135_test.dart' as fixture;

Future<void> checkFields(
  WidgetTester t,
  Finder scope, {
  bool numeric = false,
}) async {
  final fields = find.descendant(of: scope, matching: find.byType(TextField));
  expect(fields, findsWidgets);
  for (var i = 0; i < fields.evaluate().length; i++) {
    final field = fields.at(i);
    await t.ensureVisible(field);
    await t.tap(field);
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, true);
    final widget = t.widget<TextField>(field);
    final value = numeric || widget.keyboardType == TextInputType.number
        ? '2'
        : '检查';
    await t.enterText(field, value);
    await t.pumpAndSettle();
    final editable = t.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasPrimaryFocus, true);
    expect(editable.controller.text, value);
  }
}

Future<void> closeOverlay(WidgetTester t, Finder scope) async {
  Navigator.of(t.element(scope)).pop();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Note title and tag dialog accept input after switching focus', (
    t,
  ) async {
    final p = await fixture.mount(
      t,
      JournalEditorPage(
        entry: fixture.note([
          {'insert': '正文\n'},
        ]),
      ),
    );
    final title = find.byKey(const ValueKey('record-title'));
    await t.tap(title);
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, true);
    await t.enterText(title, '标题检查');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('标签'));
    await t.pumpAndSettle();
    await checkFields(t, find.byType(AppAlertDialog));
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    await t.tap(title);
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, true);
    expect(t.takeException(), null);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('Record search and both collection name modes accept input', (
    t,
  ) async {
    final p = await fixture.mount(t, const JournalPage());
    await checkFields(t, find.byType(JournalPage));
    await t.tap(find.byTooltip('新建合集'));
    await t.pumpAndSettle();
    await checkFields(t, find.byType(JournalCollectionDialog));
    await closeOverlay(t, find.byType(JournalCollectionDialog));
    await t.pumpWidget(const SizedBox());
    p.dispose();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: JournalCollectionDialog(title: '现有合集')),
      ),
    );
    await t.pumpAndSettle();
    await checkFields(t, find.byType(JournalCollectionDialog));
    expect(t.takeException(), null);
  });

  testWidgets('Table dimensions and every cell accept numeric or text input', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showJournalTableDialog(context),
                  child: const Text('插表'),
                ),
                JournalTable(
                  data: JournalTableData.empty(2, 2),
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await checkFields(t, find.byType(JournalTable));
    await t.tap(find.text('插表'));
    await t.pumpAndSettle();
    final rows = find.byKey(const ValueKey('table-rows'));
    final cols = find.byKey(const ValueKey('table-columns'));
    for (final field in [rows, cols]) {
      await t.tap(field);
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, true);
      await t.enterText(field, '2');
      await t.pumpAndSettle();
      expect(t.widget<TextField>(field).controller!.text, '2');
    }
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(t.takeException(), null);
  });

  testWidgets(
    'Todo add variants, edit variants and collection rename accept input',
    (t) async {
      final p = await fixture.mount(t, const TodoPage());
      for (final type in ['普通事项', '每日打卡', '合集']) {
        await t.tap(find.byType(FloatingActionButton));
        await t.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        if (type != '普通事项') {
          await t.tap(find.descendant(of: sheet, matching: find.text(type)));
        }
        await t.pumpAndSettle();
        await checkFields(t, sheet);
        await closeOverlay(t, sheet);
      }
      p.addNormalTask('普通编辑检查');
      p.addDailyTask('打卡编辑检查');
      p.addCollection('合集改名检查');
      await t.pumpAndSettle();
      for (final title in ['普通编辑检查', '打卡编辑检查']) {
        final item = find.text(title);
        await t.ensureVisible(item);
        await t.longPress(item);
        await t.pumpAndSettle();
        await checkFields(t, find.byType(BottomSheet));
        await closeOverlay(t, find.byType(BottomSheet));
      }
      await t.ensureVisible(find.text('合集改名检查'));
      await t.longPress(find.text('合集改名检查'));
      await t.pumpAndSettle();
      await t.tap(find.text('修改合集名称'));
      await t.pumpAndSettle();
      await checkFields(t, find.byType(AppAlertDialog));
      expect(t.takeException(), null);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets('Calendar names, date and time input modes accept input', (
    t,
  ) async {
    final p = await fixture.mount(t, const CyclePage());
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await checkFields(t, find.byType(AppAlertDialog));
    await closeOverlay(t, find.byType(AppAlertDialog));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDateTimeSheet(
                context,
                initialDate: DateTime(2026, 10, 26, 10),
              ),
              child: const Text('选择时间'),
            ),
          ),
        ),
      ),
    );
    p.dispose();
    await t.pumpAndSettle();
    await t.tap(find.text('选择时间'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Switch to input'));
    await t.pumpAndSettle();
    final date = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    );
    await t.tap(date);
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, true);
    await t.enterText(date, '10/27/2026');
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await checkFields(t, find.byType(TimePickerDialog), numeric: true);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(t.takeException(), null);
  });
}
