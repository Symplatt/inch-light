import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/main.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/widgets/journal_body.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Fixed collections survive completion and unfix removes completed group',
    () async {
      final p = AppProvider();
      await p.ready;
      p.addCollection('固定');
      final id = p.collections.single.id;
      p.toggleCollectionFixed(id);
      p.addNormalTask('事项', collectionId: id);
      p.completeCollection(id);
      expect(p.collections.single.isFixed, true);
      expect(p.normalTasks.single.collectionId, id);
      final backup = p.exportData();
      expect(await p.importData(backup), true);
      expect(p.collections.single.isFixed, true);
      p.toggleCollectionFixed(id);
      expect(p.collections, isEmpty);
      expect(p.normalTasks.single.isCompleted, true);
      expect(p.normalTasks.single.collectionId, isNull);
      p.dispose();
    },
  );
  test(
    'Heading weight and quote paragraph spacing remain distinct; punctuation includes quotes',
    () {
      final result = transformJournalDocument([
        {
          'insert': '标题',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {
          'insert': '正文',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ], JournalOperation.removeBold);
      expect(result.first['attributes']['bold'], true);
      expect(journalStyles().h1!.style.fontWeight, FontWeight.w700);
      expect(journalStyles().h2!.style.fontWeight, FontWeight.w700);
      expect(journalStyles().h3!.style.fontWeight, FontWeight.w700);
      expect(journalStyles().quote!.lineSpacing.bottom, greaterThan(0));
      final quote = transformJournalDocument([
        {'insert': '，引用'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ], JournalOperation.removeLeadingPunctuation);
      expect(quill.Document.fromJson(quote).toPlainText(), '引用。\n');
      expect(quote.last['attributes']['blockquote'], true);
    },
  );
  testWidgets(
    'Title return inserts a leading body paragraph with caret at start',
    (t) async {
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final note = JournalEntry(
        id: 'return',
        title: '标题',
        document: [
          {'insert': '原正文\n'},
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(home: JournalEditorPage(entry: note)),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('record-title')));
      await t.enterText(find.byKey(const ValueKey('record-title')), '标题');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      expect(editor.controller.document.toPlainText(), '\n原正文\n');
      expect(editor.controller.selection.baseOffset, 0);
      expect(editor.focusNode.hasFocus, true);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  testWidgets('Left swipe exits note multiselect without deleting', (t) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await t.runAsync(
      () => p.saveJournalEntry(
        JournalEntry(
          id: 'swipe',
          title: '左滑退出',
          document: [
            {'insert': '正文\n'},
          ],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: JournalPage()),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(find.text('左滑退出'), const Offset(150, 0));
    await t.pumpAndSettle();
    expect(find.byTooltip('退出多选'), findsOneWidget);
    await t.drag(find.text('左滑退出'), const Offset(-150, 0));
    await t.pumpAndSettle();
    expect(find.byTooltip('退出多选'), findsNothing);
    expect(p.journalEntries, hasLength(1));
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets('Completed, partial-display and settings help icons align', (
    t,
  ) async {
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    p.addCollection('空合集');
    await t.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const MyApp()),
    );
    await t.pumpAndSettle();
    final x = t.getCenter(find.byIcon(Icons.filter_list)).dx;
    expect(t.getCenter(find.byIcon(Icons.circle_outlined)).dx, closeTo(x, .1));
    await t.tap(find.text('设置').last);
    await t.pumpAndSettle();
    expect(t.getCenter(find.byIcon(Icons.help_outline)).dx, closeTo(x, .1));
    await t.tap(find.byTooltip('软件信息'));
    await t.pumpAndSettle();
    expect(find.textContaining('固定合集不会自动移除'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
