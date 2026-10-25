import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/utils/journal_operations.dart';

void main() {
  test('Operations preserve code words and internal spaces across styles', () {
    final source = [
      {'insert': 'hello  '},
      {
        'insert': '  lower ',
        'attributes': {'code': true},
      },
      {
        'insert': ' case  中a+b  ',
        'attributes': {'code': true, 'bold': true},
      },
      {'insert': '  world\n'},
    ];
    final capital = transformJournalDocument(
      source,
      JournalOperation.capitalize,
    );
    expect(
      q.Document.fromJson(capital).toPlainText(),
      'Hello    lower  case  中a+b    World\n',
    );
    final spaced = transformJournalDocument(
      source,
      JournalOperation.normalizeSpaces,
    );
    expect(
      q.Document.fromJson(spaced).toPlainText(),
      'hellolower  case  中a+bworld\n',
    );
    expect(
      spaced
          .where((op) => op['attributes']?['code'] == true)
          .map((op) => op['insert'])
          .join(),
      'lower  case  中a+b',
    );
    expect(spaced.any((op) => op['attributes']?['bold'] == true), true);
    expect(
      transformJournalDocument(spaced, JournalOperation.normalizeSpaces),
      spaced,
    );
    expect(
      availableJournalOperations([
        {
          'insert': 'lower case',
          'attributes': {'code': true},
        },
        {'insert': '\n'},
      ]),
      isNot(contains(JournalOperation.capitalize)),
    );
  });

  testWidgets(
    'Operations and undo remain browsing; tapping a scrolled note keeps the caret visible',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'journal_operation_chain': ['capitalize', 'normalizeSpaces'],
      });
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final note = JournalEntry(
        id: 'v3132',
        title: '检查',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        document: [
          {
            'insert':
                '${List.generate(55, (i) => '第$i行 hello world').join('\n')}\n',
          },
        ],
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(home: JournalEditorPage(entry: note)),
        ),
      );
      await t.pumpAndSettle();
      final finder = find.byType(q.QuillEditor);
      var editor = t.widget<q.QuillEditor>(finder);
      final inputCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.textInput, (
        call,
      ) async {
        inputCalls.add(call);
        return null;
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(SystemChannels.textInput, null),
      );
      for (final action in ['首字母大写', '连携操作']) {
        await t.tap(find.byTooltip('操作'));
        await t.pumpAndSettle();
        await t.tap(find.text(action));
        await t.pumpAndSettle();
        // Late controller notifications must not reopen the input connection.
        editor.controller.notifyListeners();
        editor.controller.notifyListeners();
        await t.pump(const Duration(milliseconds: 700));
        expect(editor.focusNode.hasFocus, false);
        expect(
          inputCalls.where((call) => call.method == 'TextInput.show'),
          isEmpty,
        );
        await t.tap(find.text('撤回'));
        await t.pumpAndSettle();
      }
      final page = t
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('record-page-scroll')),
          )
          .controller!;
      page.jumpTo(1300);
      await t.pumpAndSettle();
      const tap = Offset(120, 330);
      await t.tapAt(tap);
      await t.pump(const Duration(milliseconds: 100));
      editor = t.widget<q.QuillEditor>(finder);
      final selection = editor.controller.selection;
      expect(editor.focusNode.hasPrimaryFocus, true);
      expect(selection.extentOffset, greaterThan(100));
      // Reproduce a competing focus reveal during the keyboard transition.
      page.jumpTo(0);
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      final render = editor.config.editorKey!.currentState!.renderEditor;
      final caret = render.getLocalRectForCaret(selection.extent);
      final location = render.localToGlobal(caret.center);
      expect(page.offset, greaterThan(1000));
      expect(location.dy, closeTo(tap.dy, 40));
      expect(editor.controller.selection, selection);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
