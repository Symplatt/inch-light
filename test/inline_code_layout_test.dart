import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/src/editor/widgets/proxy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';

void main() {
  for (final (width, scale, ordered) in [
    (700.0, 1.0, false),
    (280.0, 1.0, false),
    (700.0, 1.5, false),
    (700.0, 1.0, true),
    (280.0, 1.5, true),
  ]) {
    testWidgets(
      'Inline code reserves space and maps editing offsets at width $width scale $scale ordered $ordered',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final p = AppProvider();
        await t.runAsync(() => p.ready);
        final original = <dynamic>[
          {'insert': '这句话有'},
          {
            'insert': '行内',
            'attributes': {'code': true},
          },
          {
            'insert': '代码',
            'attributes': {'code': true, 'bold': true},
          },
          if (ordered) ...[
            {'insert': '但是有些BUG'},
            {
              'insert': '\n',
              'attributes': {'list': 'ordered'},
            },
          ] else
            {'insert': '但是有些BUG\n'},
        ];
        final note = JournalEntry(
          id: 'padding',
          title: '行内代码间距',
          document: original,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
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
              home: RepaintBoundary(
                key: const ValueKey('review'),
                child: JournalEditorPage(entry: note),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final proxyFinder = find.byWidgetPredicate(
          (w) => w is RichTextProxy && w.inlineCodeOffsets.padding.isNotEmpty,
        );
        expect(proxyFinder, findsOneWidget);
        final proxy = t.renderObject<RenderParagraphProxy>(proxyFinder);
        // Adjacent code fragments share their two outside boundaries.
        expect(proxy.inlineCodeOffsets.padding, hasLength(2));
        Rect box(int start, int end) => proxy
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: end),
            )
            .single
            .toRect();
        final background = proxy.getInlineCodeBoxes(
          const TextRange(start: 4, end: 8),
        );
        final before = box(3, 4);
        final codeStart = box(4, 5);
        final codeEnd = box(7, 8);
        final after = box(8, 9);
        // Background geometry must stay within the reserved space, even in lists.
        expect(background.first.left, greaterThanOrEqualTo(before.right - .2));
        expect(background.last.right, lessThanOrEqualTo(after.left + .2));
        if (width == 700) {
          expect(codeStart.left - before.right, closeTo(10 * scale, .2));
          expect(after.left - codeEnd.right, closeTo(10 * scale, .2));
        }
        for (var i = 0; i < '这句话有行内代码但是有些BUG'.length; i++) {
          final char = box(i, i + 1);
          final position = proxy.getPositionForOffset(
            Offset(char.left + char.width * .2, char.center.dy),
          );
          expect(
            position.offset,
            ordered && width == 280 ? anyOf(i, i + 1) : i,
            reason: 'Hit testing character $i',
          );
          final caret = proxy.getOffsetForCaret(
            TextPosition(offset: i),
            Rect.zero,
          );
          expect(caret.dx, closeTo(char.left, .3), reason: 'Caret at $i');
        }
        final editor = t.widget<quill.QuillEditor>(
          find.byType(quill.QuillEditor),
        );
        expect(editor.controller.document.toDelta().toJson(), original);
        expect(editor.controller.document.toPlainText(), '这句话有行内代码但是有些BUG\n');
        final word = proxy.getWordBoundary(const TextPosition(offset: 13));
        expect(word, const TextRange(start: 12, end: 15));
        if (width == 700 && scale == 1) {
          editor.focusNode.canRequestFocus = true;
          editor.focusNode.requestFocus();
          editor.controller.updateSelection(
            const TextSelection.collapsed(offset: 5),
            quill.ChangeSource.local,
          );
          await t.pump();
          const composing = '这句话有行测内代码但是有些BUG\n';
          t.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: composing,
              selection: TextSelection.collapsed(offset: 6),
              composing: TextRange(start: 5, end: 6),
            ),
          );
          await t.pump();
          expect(editor.controller.document.toPlainText(), composing);
          expect(t.takeException(), isNull);
          t.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: composing,
              selection: TextSelection.collapsed(offset: 6),
            ),
          );
          await t.pump();
          t.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: '这句话有行内代码但是有些BUG\n',
              selection: TextSelection.collapsed(offset: 5),
            ),
          );
          await t.pump();
          expect(editor.controller.document.toPlainText(), '这句话有行内代码但是有些BUG\n');
          expect(editor.controller.document.toDelta().toJson(), original);
        }
        await t.pumpWidget(const SizedBox());
        p.dispose();
      },
    );
  }
}
