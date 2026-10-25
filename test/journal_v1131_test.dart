import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_quill/src/editor/widgets/proxy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/utils/journal_controller.dart';

void main() {
  test('First list item unlists at its start without changing text', () {
    for (final kind in ['ordered', 'bullet', 'checked', 'unchecked']) {
      for (final prefix in ['', '正文\n']) {
        final c = JournalController(
          document: q.Document.fromJson([
            if (prefix.isNotEmpty) {'insert': prefix},
            {'insert': '首项'},
            {
              'insert': '\n',
              'attributes': {'list': kind},
            },
            {'insert': '次项'},
            {
              'insert': '\n',
              'attributes': {'list': kind},
            },
          ]),
          selection: TextSelection.collapsed(offset: prefix.length),
        );
        final original = c.document.toPlainText();
        if (prefix.isEmpty) {
          c.onDelete!(0, false);
        } else {
          c.replaceText(
            prefix.length - 1,
            1,
            '',
            TextSelection.collapsed(offset: prefix.length - 1),
          );
        }
        expect(c.document.toPlainText(), original);
        expect(
          c.document.queryChild(prefix.length).node!.style.attributes['list'],
          isNull,
        );
        expect(
          c.document
              .queryChild(prefix.length + 3)
              .node!
              .style
              .attributes['list']
              ?.value,
          kind,
        );
        expect(c.selection.baseOffset, prefix.length);
        c.dispose();
      }
    }
  });

  testWidgets(
    'Code background starts at prose edge and checkbox preserves input state',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final note = JournalEntry(
        id: 'review',
        title: '排版',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        document: [
          {'insert': '正文\n'},
          {
            'insert': 'code',
            'attributes': {'code': true},
          },
          {'insert': '\n'},
          {'insert': '选框'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          for (final kind in ['bullet', 'ordered']) ...[
            {'insert': '$kind首项'},
            {
              'insert': '\n',
              'attributes': {'list': kind},
            },
            {'insert': '$kind次项'},
            {
              'insert': '\n',
              'attributes': {'list': kind},
            },
          ],
        ],
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(home: JournalEditorPage(entry: note)),
        ),
      );
      await t.pumpAndSettle();
      final proxy = t.renderObject<RenderParagraphProxy>(
        find.byWidgetPredicate(
          (w) => w is RichTextProxy && w.inlineCodeOffsets.padding.isNotEmpty,
        ),
      );
      expect(
        proxy.getInlineCodeBoxes(const TextRange(start: 0, end: 4)).first.left,
        closeTo(3.5, .1),
      );
      expect(
        proxy.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx,
        closeTo(10.5, .1),
      );
      final editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
      await t.tap(find.byType(Checkbox));
      await t.pumpAndSettle();
      expect(editor.focusNode.hasFocus, isFalse);
      expect(t.testTextInput.isVisible, isFalse);
      editor.focusNode.requestFocus();
      await t.pumpAndSettle();
      expect(editor.focusNode.hasPrimaryFocus, isTrue);
      expect(t.testTextInput.isVisible, isTrue);
      t.testTextInput.log.clear();
      await t.tap(find.byType(Checkbox));
      await t.pumpAndSettle();
      expect(editor.focusNode.hasPrimaryFocus, isTrue);
      expect(t.testTextInput.isVisible, isTrue);
      expect(
        t.testTextInput.log.where(
          (c) =>
              c.method == 'TextInput.hide' ||
              c.method == 'TextInput.clearClient',
        ),
        isEmpty,
      );
      t.testTextInput.hide();
      t.testTextInput.log.clear();
      await t.tap(find.byType(Checkbox));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      expect(
        t.testTextInput.log.where((c) => c.method == 'TextInput.show'),
        isEmpty,
      );
      for (final first in ['选框', 'bullet首项', 'ordered首项']) {
        final at = editor.controller.document.toPlainText().indexOf(first);
        editor.controller.updateSelection(
          TextSelection.collapsed(offset: at),
          q.ChangeSource.local,
        );
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.backspace);
        await t.pumpAndSettle();
        expect(
          editor.controller.document
              .queryChild(at)
              .node!
              .style
              .attributes['list'],
          isNull,
        );
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      p.dispose();
    },
  );
}
