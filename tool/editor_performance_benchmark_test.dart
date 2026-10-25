import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/utils/journal_controller.dart';

class CountingController extends JournalController {
  CountingController()
    : super(
        document: q.Document()..insert(0, '样例正文'),
        selection: const TextSelection.collapsed(offset: 1),
      );
  int queries = 0;
  @override
  q.Style getSelectionStyle() {
    queries++;
    return super.getSelectionStyle();
  }
}

void main() {
  testWidgets('Controlled long-note selection and keyboard-inset benchmark', (
    t,
  ) async {
    // This opt-in benchmark is executed by flutter test, outside test/.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    final provider = AppProvider();
    await t.runAsync(() => provider.ready);
    final doc = <Map<String, dynamic>>[];
    for (var i = 0; i < 350; i++) {
      doc.add({'insert': '段落 $i '});
      doc.add({
        'insert': List.filled(12, '用于测量编辑响应的正文内容，保留完整中文与英文 Flutter。').join(),
        'attributes': {'bold': i.isEven},
      });
      doc.add({'insert': '\n'});
    }
    final note = JournalEntry(
      id: 'benchmark',
      title: '性能验证',
      document: doc,
      createdAt: DateTime(2026, 10, 21, 12),
      updatedAt: DateTime(2026, 10, 21, 12),
    );
    final key = GlobalKey();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: JournalEditorPage(entry: note),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final output =
        Platform.environment['PERF_OUTPUT'] ?? 'build/editor-performance.json';
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    final editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
    final tap = Stopwatch()..start();
    await t.tapAt(
      t.getTopLeft(find.byType(q.QuillEditor)) + const Offset(75, 25),
    );
    await t.pump();
    tap.stop();
    expect(t.testTextInput.isVisible, true);
    final selections = <int>[];
    final frames = <int>[];
    for (var i = 0; i < 35; i++) {
      final sw = Stopwatch()..start();
      editor.controller.updateSelection(
        TextSelection.collapsed(offset: 20 + i),
        q.ChangeSource.local,
      );
      sw.stop();
      selections.add(sw.elapsedMicroseconds);
      await t.pump();
    }
    for (var i = 0; i < 12; i++) {
      t.view.viewInsets = FakeViewPadding(bottom: 150.0 + i * 12);
      final sw = Stopwatch()..start();
      await t.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$output.editing.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    selections.sort();
    frames.sort();
    await t.pumpWidget(const SizedBox());
    provider.dispose();
    final counting = CountingController();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalFormatBar(
            controller: counting,
            onFormat: () {},
            onTable: () {},
          ),
        ),
      ),
    );
    await t.pump();
    final result = {
      'operations': doc.length,
      'tap_to_show_frame_us': tap.elapsedMicroseconds,
      'selection_median_us': selections[selections.length ~/ 2],
      'selection_p95_us': selections[(selections.length * .95).floor()],
      'inset_frame_median_us': frames[frames.length ~/ 2],
      'toolbar_style_queries': counting.queries,
    };
    await t.runAsync(() => File(output).writeAsString(jsonEncode(result)));
    // ignore: avoid_print
    print(jsonEncode(result));
    await t.pumpWidget(const SizedBox());
    counting.dispose();
  });
}
