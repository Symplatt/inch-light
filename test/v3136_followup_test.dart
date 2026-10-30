import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_markdown_import.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'journal_v3135_test.dart' as f;

void main() {
  testWidgets(
    'Completed normal items expire exactly seven days after completion',
    (t) async {
      var now = DateTime(2026, 10, 30, 12);
      Map<String, dynamic> task(String id, bool completed, DateTime finished) =>
          {
            'id': id,
            'title': id,
            'type': 2,
            'isCompleted': completed,
            'finishedAt': finished.toIso8601String(),
            'createdAt': DateTime(2026).toIso8601String(),
          };
      SharedPreferences.setMockInitialValues({
        'normal_tasks': jsonEncode([
          task('expired', true, now.subtract(const Duration(days: 7))),
          task(
            'almost',
            true,
            now
                .subtract(const Duration(days: 7))
                .add(const Duration(seconds: 1)),
          ),
          task('unchecked', false, now.subtract(const Duration(days: 8))),
        ]),
      });
      final p = AppProvider(now: () => now);
      await t.runAsync(() => p.ready);
      expect(p.normalTasks.map((x) => x.id), ['almost', 'unchecked']);
      now = now.add(const Duration(seconds: 1));
      p.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(p.normalTasks.map((x) => x.id), ['unchecked']);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  test(
    'Markdown H2 H3 H4 map to note H1 H2 H3 and inline paste is complete',
    () {
      final parsed = journalMarkdownInsertion('## 一级\n### 二级\n#### 三级\n')!;
      expect(
        parsed.delta
            .toJson()
            .where((op) => op['attributes']?['header'] != null)
            .map((op) => op['attributes']['header']),
        [1, 2, 3],
      );
      final inline = journalMarkdownInsertion('**hello** `code`')!;
      expect(inline.delta.toList().map((op) => op.data).join(), 'hello code');
    },
  );
  test('Extended Markdown keeps highlight, underline and scripts', () {
    final ops = journalMarkdownInsertion(
      '==**高亮**== <u>下划线</u> ^上标^ ~下标~',
    )!.delta.toJson();
    for (final key in ['background', 'underline', 'script'])
      expect(ops.any((op) => op['attributes']?[key] != null), true);
    expect(
      ops.any(
        (op) =>
            op['attributes']?['background'] != null &&
            op['attributes']?['bold'] == true,
      ),
      true,
    );
  });
  test(
    'Caret cancels one full continuous format while preserving others and boundaries',
    () {
      for (final attr in <q.Attribute>[
        q.Attribute.bold,
        q.Attribute.italic,
        q.Attribute.strikeThrough,
        q.Attribute.underline,
        const q.BackgroundAttribute('#ffff00'),
        q.Attribute.inlineCode,
      ]) {
        final c = JournalController(
          document: q.Document.fromJson([
            {
              'insert': '甲乙',
              'attributes': {attr.key: attr.value},
            },
            {
              'insert': '丙丁',
              'attributes': {
                attr.key: attr.value,
                'link': 'https://example.com',
              },
            },
            {'insert': '\n'},
          ]),
          selection: const TextSelection.collapsed(offset: 1),
        );
        expect(c.clearInlineAtCaret(attr), true);
        expect(
          c.document.toDelta().toJson().any(
            (op) => op['attributes']?[attr.key] == attr.value,
          ),
          false,
        );
        expect(
          c.document.toDelta().toJson().any(
            (op) => op['attributes']?['link'] != null,
          ),
          true,
        );
        c.dispose();
        for (final edge in [0, 4]) {
          final e = JournalController(
            document: q.Document.fromJson([
              {
                'insert': '甲乙丙丁',
                'attributes': {attr.key: attr.value},
              },
              {'insert': '\n'},
            ]),
            selection: TextSelection.collapsed(offset: edge),
          );
          expect(e.clearInlineAtCaret(attr), false);
          e.dispose();
        }
      }
    },
  );
  testWidgets(
    'Copy partial heading with body and lists preserves paragraph and inline syntax',
    (t) async {
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final c = JournalController(
        document: q.Document.fromJson([
          {'insert': '三级'},
          {
            'insert': '\n',
            'attributes': {'header': 3},
          },
          {
            'insert': '列表',
            'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked', 'blockquote': true},
          },
        ]),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      expect(c.clipboardSelection(true), true);
      await t.pump();
      expect(copied, contains('#### 三级'));
      expect(copied, contains('> - [ ] **列表**'));
      final parsed = journalMarkdownInsertion(copied!)!.delta.toJson();
      expect(parsed.any((op) => op['attributes']?['header'] == 3), true);
      expect(
        parsed.any(
          (op) =>
              op['attributes']?['list'] == 'unchecked' &&
              op['attributes']?['blockquote'] == true,
        ),
        true,
      );
      c.dispose();
    },
  );
  testWidgets('Leading Markdown H1 becomes title only in empty note', (
    t,
  ) async {
    final p = await f.mount(t, const JournalEditorPage());
    final c = t.widget<q.QuillEditor>(find.byType(q.QuillEditor)).controller;
    c.replaceText(0, 0, '# 笔记标题\n\n## 正文标题\n- 列表', null);
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('record-title')))
          .controller!
          .text,
      '笔记标题',
    );
    expect(c.document.toPlainText(), contains('正文标题'));
    expect(
      c.document.toDelta().toJson().any(
        (op) => op['attributes']?['header'] == 1,
      ),
      true,
    );
    c.replaceText(0, 0, '# 保留正文\n', null);
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('record-title')))
          .controller!
          .text,
      '笔记标题',
    );
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
