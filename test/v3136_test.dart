import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/main_screen.dart';
import 'package:inch_light/models/task_model.dart';
import 'package:inch_light/utils/journal_title_controller.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/widgets/todo_visibility_dialog.dart';
import 'journal_v3135_test.dart' as f;

void main() {
  test('Title chain preserves Markdown formatting and code content', () {
    expect(
      transformJournalTitle('**hello** `code`', JournalOperation.capitalize),
      '**Hello** `code`',
    );
    expect(
      transformJournalTitle(
        '**标题**',
        JournalOperation.removeLeadingPunctuation,
      ),
      '**标题。**',
    );
    expect(transformJournalTitle('**标题**', JournalOperation.removeBold), '标题');
    expect(
      transformJournalTitle('==高亮== <u>下划线</u>', JournalOperation.capitalize),
      '==高亮== <u>下划线</u>',
    );
  });
  testWidgets(
    'Title renders complete syntax while copying original source and composing normally',
    (t) async {
      final c = JournalTitleController(text: '**粗体** `code` *斜体* ==高亮==');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: c)),
        ),
      );
      final context = t.element(find.byType(TextField));
      final span = c.buildTextSpan(
        context: context,
        style: const TextStyle(fontSize: 30),
        withComposing: false,
      );
      expect(span.toPlainText(), c.text);
      expect(
        span.children!.whereType<TextSpan>().any(
          (s) => s.style?.fontWeight == FontWeight.w600,
        ),
        true,
      );
      await t.tap(find.byType(TextField));
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      final editable = t.state<EditableTextState>(find.byType(EditableText));
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData')
          copied = call.arguments['text'] as String;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      editable.copySelection(SelectionChangedCause.toolbar);
      await t.pump();
      expect(copied, c.text);
      c.value = const TextEditingValue(
        text: '**输入**',
        composing: TextRange(start: 2, end: 4),
      );
      expect(
        c.buildTextSpan(context: context, withComposing: true).toPlainText(),
        '**输入**',
      );
      final entry = f.note([
        {'insert': '正文\n'},
      ]);
      final json = entry.toJson()..['title'] = '**粗体** `code`';
      expect(
        journalToMarkdown(JournalEntry.fromJson(json)),
        startsWith('# **粗体** `code`'),
      );
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'Visible collections precede hidden ones without jumping when toggled',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: TodoVisibilityDialog(
            collections: [
              TaskCollection(id: 'h', title: '隐藏'),
              TaskCollection(id: 'v', title: '显示'),
            ],
            visible: const {'v'},
          ),
        ),
      );
      expect(
        t.getTopLeft(find.text('显示')).dy,
        lessThan(t.getTopLeft(find.text('隐藏')).dy),
      );
      await t.tap(find.text('隐藏'));
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('显示')).dy,
        lessThan(t.getTopLeft(find.text('隐藏')).dy),
      );
    },
  );

  testWidgets(
    'Move preserves task fields; exported preferences restore to a fresh install',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'journal_operation_chain': ['capitalize'],
        'loose_tasks_first': true,
        'countdowns_first': false,
      });
      final p = AppProvider();
      await p.ready;
      p.addCollection('目标');
      final id = p.collections.single.id;
      await p.setVisibleTodoCollections({});
      p.addNormalTask('事项', tags: ['标签'], deadline: DateTime(2030));
      final task = p.normalTasks.single;
      p.moveTask(task, id);
      expect(task.collectionId, id);
      expect(task.tags, ['标签']);
      expect(task.deadline, DateTime(2030));
      p.moveTask(task, null);
      expect(task.collectionId, null);
      final backup = p.exportData();
      p.dispose();
      SharedPreferences.setMockInitialValues({});
      final restored = AppProvider();
      await restored.ready;
      expect(await restored.importData(backup), true);
      final after = jsonDecode(restored.exportData());
      expect(after['preferences'], jsonDecode(backup)['preferences']);
      expect(restored.isTodoCollectionVisible(id), false);
      restored.dispose();
    },
  );

  testWidgets(
    'Menu chain stays browsing and explicit title/body taps reopen keyboard',
    (t) async {
      final p = await f.mount(
        t,
        JournalEditorPage(
          entry: f.note([
            {'insert': 'hello\n'},
          ]),
        ),
        prefs: {
          'journal_operation_chain': ['capitalize'],
        },
      );
      await t.tap(find.byTooltip('操作'));
      await t.pumpAndSettle();
      await t.tap(find.text('连携操作'));
      await t.pumpAndSettle();
      var editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
      expect(editor.focusNode.hasFocus, false);
      expect(t.testTextInput.isVisible, false);
      await t.tap(find.byKey(const ValueKey('record-title')));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, true);
      await t.enterText(find.byKey(const ValueKey('record-title')), '**标题**');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.tapAt(
        t.getTopLeft(find.byType(q.QuillEditor)) + const Offset(60, 20),
      );
      await t.pumpAndSettle();
      editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
      expect(editor.focusNode.hasPrimaryFocus, true);
      expect(t.testTextInput.isVisible, true);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets('Header swipes switch adjacent modules and body swipes do not', (
    t,
  ) async {
    final p = await f.mount(t, const MainScreen());
    await t.dragFrom(const Offset(190, 28), const Offset(-130, 0));
    await t.pumpAndSettle();
    expect(p.lastModule, 'journal');
    await t.dragFrom(const Offset(190, 740), const Offset(-130, 0));
    await t.pumpAndSettle();
    expect(p.lastModule, 'journal');
    await t.dragFrom(const Offset(190, 28), const Offset(130, 0));
    await t.pumpAndSettle();
    expect(p.lastModule, 'todo');
    await t.dragFrom(const Offset(190, 28), const Offset(130, 0));
    await t.pumpAndSettle();
    expect(p.lastModule, 'todo');
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
