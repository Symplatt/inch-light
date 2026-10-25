import 'package:inch_light/widgets/journal_format_icon.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_image_page.dart';
import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/widgets/journal_chain_dialog.dart';

JournalEntry note() => JournalEntry(
  id: 'test',
  title: '测试',
  document: [
    {
      'insert': '，正文',
      'attributes': {'color': '#0000FF', 'background': '#00FF00'},
    },
    {'insert': '\n'},
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Legacy split punctuation chains become one operation at the first position',
    () {
      expect(
        normalizeJournalOperations([
          JournalOperation.normalizeSpaces,
          JournalOperation.addSentencePeriods,
          JournalOperation.capitalize,
          JournalOperation.removeLeadingPunctuation,
        ]),
        [
          JournalOperation.normalizeSpaces,
          JournalOperation.removeLeadingPunctuation,
          JournalOperation.capitalize,
        ],
      );
    },
  );

  testWidgets(
    'Punctuation tap performs both actions directly and undoes once',
    (t) async {
      final provider = AppProvider();
      await t.runAsync(() => provider.ready);
      final original = note();
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: JournalEditorPage(entry: original)),
        ),
      );
      await t.pumpAndSettle();
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      await t.tap(find.byTooltip('操作'));
      await t.pumpAndSettle();
      expect(find.text('文本整理'), findsOneWidget);
      expect(find.text('格式调整'), findsNothing);
      final menu = t.widget<PopupMenuButton<JournalOperation>>(
        find.byType(PopupMenuButton<JournalOperation>),
      );
      expect(menu.constraints!.maxWidth, 224);
      for (final symbol in [
        JournalFormatSymbol.headingUp,
        JournalFormatSymbol.headingDown,
      ]) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is JournalFormatIcon && widget.symbol == symbol,
          ),
          findsNothing,
        );
      }
      await t.tap(find.text('标点管理'));
      await t.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing);
      expect(editor.controller.document.toPlainText(), '正文。\n');
      expect(find.text('已标点管理'), findsOneWidget);
      expect(t.testTextInput.isVisible, false);
      await t.tap(find.text('撤回'));
      await t.pumpAndSettle();
      expect(editor.controller.document.toPlainText(), '，正文\n');
      expect(editor.controller.document.toDelta().toJson(), original.document);
      final theme = Theme.of(t.element(find.byType(quill.QuillEditor)));
      for (final color in [
        theme.colorScheme.primary,
        theme.colorScheme.secondary,
        theme.colorScheme.tertiary,
        theme.colorScheme.error,
        theme.textSelectionTheme.cursorColor!,
        theme.textSelectionTheme.selectionColor!,
        theme.textSelectionTheme.selectionHandleColor!,
      ]) {
        expect(color.r, closeTo(color.g, .0001));
        expect(color.g, closeTo(color.b, .0001));
      }
      await t.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );

  testWidgets('Chain editor displays only the unified punctuation entry', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JournalChainDialog(
            operations: [
              JournalOperation.addSentencePeriods,
              JournalOperation.removeLeadingPunctuation,
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('标点管理'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('•'), findsWidgets);
    expect(find.textContaining('补全句号'), findsNothing);
    expect(find.textContaining('清理段首标点'), findsNothing);
  });

  testWidgets(
    'Whole-row long press selects, reorders and removes chain items',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JournalChainDialog(
              operations: [
                JournalOperation.clearBlankLines,
                JournalOperation.normalizeSpaces,
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> move(JournalOperation operation, Offset target) async {
        final gesture = await t.startGesture(
          t.getCenter(find.byKey(ValueKey(operation))),
        );
        await t.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, -2));
        await t.pump();
        await gesture.moveTo(target);
        await t.pump(const Duration(milliseconds: 600));
        await gesture.up();
        await t.pumpAndSettle();
      }

      Finder row(JournalOperation operation) => find.byKey(ValueKey(operation));
      await move(
        JournalOperation.removeBold,
        t.getTopLeft(row(JournalOperation.clearBlankLines)) +
            const Offset(70, -24),
      );
      expect(
        find.descendant(
          of: row(JournalOperation.removeBold),
          matching: find.text('1.'),
        ),
        findsOneWidget,
      );
      await move(
        JournalOperation.normalizeSpaces,
        t.getTopLeft(row(JournalOperation.removeBold)) + const Offset(70, -24),
      );
      expect(
        find.descendant(
          of: row(JournalOperation.normalizeSpaces),
          matching: find.text('1.'),
        ),
        findsOneWidget,
      );
      await move(
        JournalOperation.normalizeSpaces,
        t.getCenter(row(JournalOperation.removeLeadingPunctuation)) +
            const Offset(0, 18),
      );
      expect(
        find.descendant(
          of: row(JournalOperation.normalizeSpaces),
          matching: find.text('•'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    },
  );

  testWidgets(
    'Export raster is grayscale even for existing colored rich text',
    (t) async {
      Uint8List? exported;
      const channel = MethodChannel('inch_light/note_export');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        exported = (call.arguments as Map)['bytes'] as Uint8List;
        return false;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final original = note();
      await t.pumpWidget(MaterialApp(home: JournalImagePage(entry: original)));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('保存图片'));
      await t.pump();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await t.pumpAndSettle();
      expect(exported, isNotNull);
      await t.runAsync(() async {
        final codec = await ui.instantiateImageCodec(exported!);
        final frame = await codec.getNextFrame();
        final rgba = (await frame.image.toByteData())!.buffer.asUint8List();
        var nonWhite = 0;
        for (var i = 0; i < rgba.length; i += 4) {
          expect((rgba[i] - rgba[i + 1]).abs(), lessThanOrEqualTo(1));
          expect((rgba[i + 1] - rgba[i + 2]).abs(), lessThanOrEqualTo(1));
          if (rgba[i] < 240) nonWhite++;
        }
        expect(nonWhite, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      });
      expect(original.document.first['attributes']['color'], '#0000FF');
      expect(original.document.first['attributes']['background'], '#00FF00');
    },
  );
}
