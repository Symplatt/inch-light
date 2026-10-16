import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/constants/app_colors.dart';
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/cycle_page.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_markdown.dart';
import 'package:inch_light/widgets/swipe_delete_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Table insertion removes only blank-line whitespace and preserves prose and undo',
    () {
      for (final sample in [
        (text: '\n', at: 0, expected: '\uFFFC\n\n'),
        (text: '   \t　\n', at: 2, expected: '\uFFFC\n\n'),
        (text: '前文\n   \n后文\n', at: 5, expected: '前文\n\uFFFC\n后文\n'),
        (text: '一整行文字\n后文\n', at: 2, expected: '一整行文字\n\uFFFC\n后文\n'),
        (text: '末行文字\n', at: 2, expected: '末行文字\n\uFFFC\n\n'),
      ]) {
        final c = JournalController(
          document: quill.Document.fromJson([
            {'insert': sample.text},
          ]),
          selection: TextSelection.collapsed(offset: sample.at),
        );
        final before = c.document.toDelta().toJson();
        c.insertTable(JournalTableData.empty(3, 2), c.selection);
        expect(c.document.toPlainText(), sample.expected);
        expect(
          c.document.toDelta().toJson().where((op) => op['insert'] is Map),
          hasLength(1),
        );
        c.undo();
        expect(c.document.toDelta().toJson(), before);
        c.dispose();
      }
      final c = JournalController(
        document: quill.Document.fromJson([
          {'insert': '   '},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered', 'indent': 2, 'align': 'center'},
          },
          {'insert': '后文'},
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
        ]),
        selection: const TextSelection.collapsed(offset: 1),
      );
      c.insertTable(JournalTableData.empty(3, 2), c.selection);
      final ops = c.document.toDelta().toJson();
      expect(ops.first['attributes'], isNull);
      expect(ops[1]['attributes'], isNull);
      expect(ops.last['attributes'], {'header': 2});
      c.dispose();
    },
  );

  testWidgets(
    'Toolbar orders highlight underline divider scripts and applies underline',
    (t) async {
      final c = JournalController(
        document: quill.Document()..insert(0, '文字'),
        selection: const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalFormatBar(
              controller: c,
              onFormat: () {},
              onTable: () {},
            ),
          ),
        ),
      );
      final labels = t
          .widgetList<IconButton>(find.byType(IconButton))
          .map((b) => b.tooltip)
          .toList();
      final first = labels.indexOf('下划线');
      expect(labels.sublist(first, first + 5), [
        '下划线',
        '高亮',
        '分隔线',
        '上标',
        '下标',
      ]);
      await t.ensureVisible(find.byTooltip('下划线'));
      await t.tap(find.byTooltip('下划线'));
      await t.pump();
      expect(c.document.toDelta().toJson().first['attributes'], {
        'underline': true,
      });
      final entry = JournalEntry(
        id: 'u',
        title: '',
        document: c.document.toDelta().toJson(),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(journalToMarkdown(entry), contains('<u>文字</u>'));
      await t.tap(find.byTooltip('下划线'));
      expect(c.document.toDelta().toJson().first['attributes'], isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'Todo and calendar moving corners are red; urgent dot paints above outline',
    (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      p.addNormalTask('事项');
      p.addCollection('合集');
      p.addCountdown('临近', DateTime.now().add(const Duration(hours: 1)));
      final boundary = GlobalKey();
      Future<void> mount(Widget page) async {
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: p,
            child: MaterialApp(
              home: RepaintBoundary(key: boundary, child: page),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      Future<Color> pixel(Offset position) async {
        late Color value;
        await t.runAsync(() async {
          final box =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await box.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pos = box.globalToLocal(position);
          final index = (pos.dy.floor() * image.width + pos.dx.floor()) * 4;
          value = Color.fromARGB(
            data.getUint8(index + 3),
            data.getUint8(index),
            data.getUint8(index + 1),
            data.getUint8(index + 2),
          );
          image.dispose();
        });
        return value;
      }

      Future<void> corners(Finder card, double dx) async {
        final dismiss = find
            .descendant(of: card, matching: find.byType(Dismissible))
            .first;
        final slide = find
            .descendant(of: dismiss, matching: find.byType(SlideTransition))
            .first;
        final gesture = await t.startGesture(t.getCenter(card));
        await gesture.moveBy(Offset(dx.sign * 20, 0));
        await t.pump();
        await gesture.moveBy(Offset(dx, 0));
        await t.pump();
        final original = t.getRect(slide);
        final rect = original.shift(
          Offset(
            t.widget<SlideTransition>(slide).position.value.dx * original.width,
            0,
          ),
        );
        final x = dx < 0 ? rect.right - 1 : rect.left;
        expect(await pixel(Offset(x, rect.top)), AppColors.danger);
        expect(await pixel(Offset(x, rect.bottom - 1)), AppColors.danger);
        await gesture.cancel();
        await t.pumpAndSettle();
      }

      await mount(const TodoPage());
      await corners(find.byType(SwipeDeleteCard).first, -70);
      await corners(find.byType(SwipeDeleteCard).last, -70);
      await mount(const CyclePage());
      final dot = find.byKey(ValueKey('completed-${p.countdowns.single.id}'));
      final dotRect = t.getRect(dot);
      // This point lies on the rounded card outline and inside the red circle.
      expect(
        await pixel(dotRect.topLeft + const Offset(3, 5)),
        const Color(0xFFF5222D),
      );
      await corners(find.byType(SwipeDeleteCard), -70);

      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
