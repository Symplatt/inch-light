import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/utils/journal_controller.dart';
import 'package:inch_light/utils/journal_editor_cache.dart';

void main() {
  test(
    'Selection reuses snapshots; text, format and history invalidate synchronously',
    () {
      final document = q.Document()..insert(0, '正文');
      final controller = JournalController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final cache = JournalEditorCache();
      String snapshot() => cache.snapshot(
        document: controller.document,
        title: '标题',
        titleBold: false,
        tags: ['标签'],
      );
      final before = snapshot();
      final revision = document.revision;
      for (var i = 0; i < 3; i++) {
        controller.updateSelection(
          TextSelection.collapsed(offset: i),
          q.ChangeSource.local,
        );
        expect(identical(snapshot(), before), true);
      }
      expect(document.revision, revision);
      String? notified;
      controller.addListener(() => notified = snapshot());
      controller.replaceText(
        0,
        0,
        '新',
        const TextSelection.collapsed(offset: 1),
      );
      expect(document.revision, greaterThan(revision));
      expect(
        jsonDecode(notified!)['document'],
        controller.document.toDelta().toJson(),
      );
      final afterText = snapshot();
      document.history.clear();
      controller.formatText(0, 1, q.Attribute.bold);
      expect(snapshot(), isNot(afterText));
      expect(
        jsonDecode(notified!)['document'].first['attributes']['bold'],
        true,
      );
      controller.undo();
      expect(snapshot(), afterText);
      controller.redo();
      expect(
        jsonDecode(snapshot())['document'].first['attributes']['bold'],
        true,
      );
      controller.dispose();
      document.close();
    },
  );
  test(
    'Document replacement and in-place tag edits cannot return a stale snapshot',
    () {
      final first = q.Document()..insert(0, '甲');
      final second = q.Document()..insert(0, '乙');
      final cache = JournalEditorCache();
      final tags = ['甲'];
      String snapshot(q.Document d, {String title = '标题', bool bold = false}) =>
          cache.snapshot(
            document: d,
            title: title,
            titleBold: bold,
            tags: tags,
          );
      final original = snapshot(first);
      final replacement = snapshot(second);
      expect(replacement, isNot(original));
      expect(jsonDecode(replacement)['document'], second.toDelta().toJson());
      tags[0] = '乙';
      expect(snapshot(second), isNot(replacement));
      expect(jsonDecode(snapshot(second))['tags'], ['乙']);
      expect(
        jsonDecode(snapshot(second, title: '新标题', bold: true))['titleBold'],
        true,
      );
      first.close();
      second.close();
    },
  );
  testWidgets(
    'Keyboard insets reuse the editor while real edits refresh metadata',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(420, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      final p = AppProvider();
      await t.runAsync(() => p.ready);
      final entry = JournalEntry(
        id: 'perf',
        title: '标题',
        document: [
          {'insert': '正文\n'},
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(home: JournalEditorPage(entry: entry)),
        ),
      );
      await t.pumpAndSettle();
      final finder = find.byType(q.QuillEditor);
      final initial = t.widget<q.QuillEditor>(finder);
      t.view.viewInsets = const FakeViewPadding(bottom: 160);
      await t.pump();
      expect(identical(t.widget(finder), initial), true);
      await t.tapAt(t.getTopLeft(finder) + const Offset(50, 25));
      await t.pumpAndSettle();
      final focused = t.widget<q.QuillEditor>(finder);
      t.view.viewInsets = const FakeViewPadding(bottom: 240);
      await t.pump();
      expect(identical(t.widget(finder), focused), true);
      focused.controller.replaceText(
        0,
        0,
        '新',
        const TextSelection.collapsed(offset: 1),
      );
      await t.pump();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('record-metadata'))).data,
        endsWith('3字'),
      );
      focused.controller.undo();
      await t.pump();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('record-metadata'))).data,
        endsWith('2字'),
      );
      final previous = focused.controller.document;
      focused.controller.document = q.Document()..insert(0, '替换文档');
      await t.pump();
      expect(identical(t.widget(finder), focused), false);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('record-metadata'))).data,
        endsWith('4字'),
      );
      previous.close();
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
