import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/task_model.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_image_page.dart';
import 'package:inch_light/utils/journal_image_capture.dart';
import 'package:inch_light/utils/journal_operations.dart';
import 'package:inch_light/widgets/journal_image_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Blue deadline survives serialization and old data defaults to false',
    () {
      final task = TaskItem(
        id: 'a',
        title: 'a',
        type: TaskType.normal,
        deadlineBlue: true,
      );
      expect(TaskItem.fromJson(task.toJson()).deadlineBlue, true);
      expect(
        TaskItem.fromJson(task.toJson()..remove('deadlineBlue')).deadlineBlue,
        false,
      );
    },
  );
  test(
    'A updates shared styles; B persists independently; indent stays export-only',
    () async {
      final original = await JournalImageSettings.load(page: true);
      expect(original.paragraphSpacing, 10);
      final a = original.copy()..fontSize = 30;
      await a.savePage(original);
      final b = await JournalImageSettings.load();
      expect(b.fontSize, 30);
      b.paragraphSpacing = 24;
      b.indent = true;
      await b.saveImage();
      expect((await JournalImageSettings.load()).paragraphSpacing, 24);
      final page = await JournalImageSettings.load(page: true);
      expect(page.paragraphSpacing, 10);
      expect(page.indent, false);
      await (page.copy()..fontSize = 28).savePage(page);
      final next = await JournalImageSettings.load();
      expect(next.fontSize, 28);
      expect(next.paragraphSpacing, 24);
      expect(next.indent, true);
    },
  );
  test(
    'Periods apply to prose/list only, preserve style and do not duplicate symbols',
    () {
      final original = <dynamic>[
        {'insert': '标题'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {
          'insert': '正文',
          'attributes': {'bold': true},
        },
        {'insert': '  \n'},
        {'insert': '列表'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
        {'insert': '完成！\n括号）\n表情🙂\n\n'},
        {'insert': 'code'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
      ];
      final result = transformJournalDocument(
        original,
        JournalOperation.addSentencePeriods,
      );
      final doc = quill.Document.fromJson(result);
      expect(doc.toPlainText(), '标题\n正文。  \n列表。\n完成！\n括号）。\n表情🙂\n\ncode\n');
      expect(
        result.firstWhere(
          (op) => (op['insert'] as String).contains('正文'),
        )['attributes']['bold'],
        true,
      );
      expect(
        transformJournalDocument(result, JournalOperation.addSentencePeriods),
        result,
      );
      doc.close();
    },
  );
  testWidgets(
    'Tiled PNG keeps device density and exact pixels across strip seams',
    (t) async {
      final key = GlobalKey();
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 31,
                  child: Column(
                    children: [
                      Container(height: 520, color: const Color(0xFFFF0000)),
                      Container(height: 520, color: const Color(0xFF0000FF)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final png = await captureJournalPng(
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
          2.75,
        );
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 86);
        expect(frame.image.height, 2860);
        final pixels = (await frame.image.toByteData())!.buffer.asUint8List();
        for (final y in [0, 1023, 1024, 1429]) {
          expect(pixels.sublist((y * 86 + 10) * 4, (y * 86 + 10) * 4 + 4), [
            255,
            0,
            0,
            255,
          ]);
        }
        for (final y in [1430, 2047, 2048, 2859]) {
          expect(pixels.sublist((y * 86 + 10) * 4, (y * 86 + 10) * 4 + 4), [
            0,
            0,
            255,
            255,
          ]);
        }
        frame.image.dispose();
        codec.dispose();
      });
    },
  );
  testWidgets(
    'Chain uses saved order and one undo; Markdown leaves keyboard hidden',
    (t) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('journal_operation_chain', [
        'removeLeadingPunctuation',
        'addSentencePeriods',
      ]);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final note = JournalEntry(
        id: 'test',
        title: '测试',
        document: [
          {'insert': '，正文\n'},
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
      await t.tap(find.byTooltip('操作'));
      await t.pumpAndSettle();
      await t.tap(find.text('连携操作'));
      await t.pumpAndSettle();
      final editor = t.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      expect(editor.controller.document.toPlainText(), '正文。\n');
      expect(editor.focusNode.hasFocus, false);
      expect(t.testTextInput.isVisible, false);
      await t.tap(find.text('撤回'));
      await t.pumpAndSettle();
      expect(editor.controller.document.toPlainText(), '，正文\n');
      await t.tap(find.byTooltip('导出'));
      await t.pumpAndSettle();
      await t.tap(find.text('复制 Markdown'));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, false);
      expect(editor.focusNode.hasFocus, false);
      await t.tap(find.byTooltip('页面设置'));
      await t.pumpAndSettle();
      expect(find.text('开头空两格'), findsNothing);
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  testWidgets(
    'Successful image export remembers settings and returns to note',
    (t) async {
      final note = JournalEntry(
        id: 'test',
        title: '测试',
        document: [
          {'insert': '正文\n'},
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      const channel = MethodChannel('inch_light/note_export');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => true,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => JournalImagePage(entry: note),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('打开'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('图片设置'));
      await t.pumpAndSettle();
      t.widget<Slider>(find.byKey(const ValueKey('image-段间距'))).onChanged!(24);
      await t.pump();
      await t.tap(find.text('完成'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('保存图片'));
      await t.pump();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await t.pumpAndSettle();
      expect(find.byType(JournalImagePage), findsNothing);
      expect((await JournalImageSettings.load()).paragraphSpacing, 24);
    },
  );
}
