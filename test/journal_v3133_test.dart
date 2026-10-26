import 'package:inch_light/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/constants/journal_colors.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/screens/settings_page.dart';
import 'package:inch_light/utils/journal_shortcuts.dart';
import 'package:inch_light/widgets/journal_body.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppProvider> mount(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(400, 850);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(home: page),
      ),
    );
    await t.pumpAndSettle();
    return p;
  }

  testWidgets('Collection edge pull resists and requires deliberate release', (
    t,
  ) async {
    final p = await mount(t, const JournalPage());
    for (var i = 0; i < 14; i++) {
      await p.addJournalCollection('合集$i');
    }
    await t.pumpAndSettle();
    final strip = find.byKey(const ValueKey('collection-tabs'));
    final scroll = t.widget<SingleChildScrollView>(strip).controller!;
    final y = t.getCenter(strip).dy;
    Future<void> drag(double dx) async {
      final g = await t.startGesture(Offset(dx > 0 ? 25 : 370, y));
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(dx / 20, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await t.pumpAndSettle();
    }

    await drag(120);
    expect(find.byType(AppAlertDialog), findsNothing);
    expect(scroll.offset, closeTo(0, .1));
    await drag(-280);
    expect(scroll.offset, greaterThan(100));
    expect(find.byType(AppAlertDialog), findsNothing);
    scroll.jumpTo(0);
    await t.pumpAndSettle();

    final gesture = await t.startGesture(Offset(25, y));
    for (var i = 0; i < 34; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(-scroll.offset, greaterThan(64));
    expect(-scroll.offset, lessThan(150));
    expect(find.byType(AppAlertDialog), findsNothing);
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('合集 · 15'), findsOneWidget);
    final surface = find
        .descendant(
          of: find.byType(AppAlertDialog),
          matching: find.byType(Material),
        )
        .first;
    final rect = t.getRect(surface);
    expect(rect.height, lessThanOrEqualTo(850 * .65));
    expect(rect.center.dx, closeTo(200, .1));
    expect(
      rect.center.dy,
      closeTo(850 * dialogCenterFraction(rect.height / 850), .1),
    );
    final collection = find.descendant(
      of: find.byType(AppAlertDialog),
      matching: find.text('合集4'),
    );
    await t.scrollUntilVisible(
      collection,
      150,
      scrollable: find.descendant(
        of: find.byType(AppAlertDialog),
        matching: find.byType(Scrollable),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(collection);
    await t.pumpAndSettle();
    expect(
      p.lastJournalCollection,
      p.journalCollections.firstWhere((c) => c.title == '合集4').id,
    );
    expect(find.byType(AppAlertDialog), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets(
    'Highlight toggles legacy gray off and adds yellow; shortcut and rendering agree',
    (t) async {
      final note = JournalEntry(
        id: 'highlight-preview',
        title: '检查',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        document: [
          {
            'insert': '旧高亮',
            'attributes': {'background': '#E6E6E6'},
          },
          {'insert': '\n'},
        ],
      );
      final p = await mount(t, JournalEditorPage(entry: note));
      final editor = t.widget<q.QuillEditor>(find.byType(q.QuillEditor));
      final c = editor.controller;
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      editor.focusNode.requestFocus();
      await t.pumpAndSettle();
      c.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
        q.ChangeSource.local,
      );
      await t.pump();
      final node = (c.document.root.children.first as q.Line).children.first;
      final span =
          journalSpan(
                t.element(find.byType(q.QuillEditor)),
                node,
                0,
                '旧高亮',
                const TextStyle(backgroundColor: Color(0xFFE6E6E6)),
                null,
              )
              as TextSpan;
      expect(span.style!.backgroundColor, journalHighlightColor);
      expect(
        c.document.toDelta().toJson().first['attributes']['background'],
        '#E6E6E6',
      );
      final button = find.byKey(const ValueKey('format-高亮'));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(c.document.collectStyle(0, 3).attributes['background'], isNull);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(
        c.document.collectStyle(0, 3).attributes['background']!.value,
        journalHighlightHex,
      );
      final shortcut = q.QuillController(
        document: q.Document.fromJson([
          {'insert': '==黄色==\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 6),
      );
      expect(applyJournalShortcut(shortcut), true);
      expect(
        shortcut.document.collectStyle(0, 2).attributes['background']!.value,
        journalHighlightHex,
      );
      shortcut.dispose();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );

  testWidgets('Software info retains metadata without the feature guide', (
    t,
  ) async {
    final p = await mount(t, const SettingsPage());
    await t.tap(find.byTooltip('软件信息'));
    await t.pumpAndSettle();
    final dialog = find.byType(AppAlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('版本 3.13.3（构建 73）')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('版权所有 © Symplatt')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('新建时可选')),
      findsNothing,
    );
    expect(find.text('开源许可'), findsOneWidget);
    await t.tap(find.text('关闭'));
    await t.pumpAndSettle();
    expect(dialog, findsNothing);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
