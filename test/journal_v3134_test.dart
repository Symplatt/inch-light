import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_markdown_import.dart';
import 'package:inch_light/utils/journal_shortcuts.dart';
import 'package:inch_light/widgets/app_dialog.dart';

void main() {
  test(
    'Paste converts a conversation, keeps code literal and supports undo',
    () {
      final editor = JournalController(
        document: q.Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );
      const source =
          '# 标题\n\n正文 **加粗**和`a*b`。\n\n'
          '- 第一项\n  - 子项\n- [x] 已完成\n\n'
          '> 引用\n\n1. 顺序\n\n```dart\n# 原样 **代码**\n```\n\n'
          '| 名称 | 状态 |\n| --- | --- |\n| A | 完成 |';
      editor.replaceText(
        0,
        0,
        source,
        const TextSelection.collapsed(offset: source.length),
      );
      final ops = editor.document.toDelta().toJson();
      bool has(String key, Object value) =>
          ops.any((op) => op['attributes']?[key] == value);
      expect(has('header', 1), true);
      expect(has('list', 'bullet'), true);
      expect(has('indent', 1), true);
      expect(has('list', 'checked'), true);
      expect(has('list', 'ordered'), true);
      expect(has('blockquote', true), true);
      expect(has('code-block', true), true);
      expect(
        ops.any(
          (op) =>
              op['insert'] is Map && (op['insert'] as Map).containsKey('table'),
        ),
        true,
      );
      expect(editor.document.toPlainText(), contains('# 原样 **代码**'));
      expect(editor.document.toPlainText(), contains('正文 加粗和a*b。'));
      expect(q.Document.fromJson(ops).toDelta(), editor.document.toDelta());
      editor.undo();
      expect(editor.document.toPlainText(), '\n');
      editor.dispose();
    },
  );

  test('Inline, selection replacement, plain text and code remain intact', () {
    expect(journalMarkdownInsertion('普通文本\n第二行'), null);
    expect(journalMarkdownInsertion(r'\# 原样标题'), null);
    final editor = JournalController(
      document: q.Document()..insert(0, '前后'),
      selection: const TextSelection.collapsed(offset: 1),
    );
    editor.replaceText(1, 0, '**中**', const TextSelection.collapsed(offset: 6));
    expect(editor.document.toPlainText(), '前中后\n');
    expect(editor.selection.baseOffset, 2);
    editor.replaceText(1, 1, '# 标题', const TextSelection.collapsed(offset: 5));
    expect(editor.document.toPlainText(), '前\n标题\n后\n');
    editor.formatText(0, 1, q.Attribute.inlineCode);
    editor.replaceText(
      1,
      0,
      '**原文**',
      const TextSelection.collapsed(offset: 7),
    );
    expect(editor.document.toPlainText(), startsWith('前**原文**'));
    editor.dispose();
  });

  test('Live shortcuts leave pasted code block markers literal', () {
    final editor = JournalController(
      document: q.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    editor.replaceText(0, 0, '```\n**原样**\n```', null);
    expect(applyJournalShortcut(editor), false);
    expect(editor.document.toPlainText(), '**原样**\n');
    editor.dispose();
  });

  testWidgets(
    'Measured dialog centers follow all boundaries and avoid keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final (height, fraction) in [
        (160.0, .45),
        (200.0, .46),
        (359.0, .46),
        (360.0, .48),
        (519.0, .48),
        (520.0, .50),
      ]) {
        showDialog<void>(
          context: context,
          builder: (_) => AppDialog(
            child: SizedBox(
              key: const ValueKey('surface'),
              width: 280,
              height: height,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byKey(const ValueKey('surface'))).dy,
          closeTo(800 * fraction, .1),
        );
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      showDialog<void>(
        context: context,
        builder: (_) =>
            const AppAlertDialog(title: Text('输入'), content: TextField()),
      );
      await tester.pumpAndSettle();
      final surface = find
          .descendant(
            of: find.byType(AppDialog),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getBottomLeft(surface).dy, lessThanOrEqualTo(450));
      expect(tester.takeException(), null);
    },
  );
}
