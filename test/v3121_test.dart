import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/todo_page.dart';
import 'package:inch_light/utils/journal_operations.dart';

void main() {
  test('Closing quotes and brackets receive a period, idempotently', () {
    for (final text in [
      '发送请求事件位于时间轴另一侧（要么下要么上）',
      '他说“内容”',
      '内容「引文」',
      '内容(说明)',
      '内容[说明]',
      '内容【说明】',
      '内容《书名》',
      '内容{说明}',
      '内容「引文」',
      '内容“引文”',
      '内容『引文』',
      '内容〈说明〉',
      '内容［说明］',
      '内容｛说明｝',
      '内容"引文"',
      "内容'引文'",
    ]) {
      final result = transformJournalDocument([
        {'insert': '$text\n'},
      ], JournalOperation.removeLeadingPunctuation);
      expect(quill.Document.fromJson(result).toPlainText(), '$text。\n');
      expect(
        transformJournalDocument(
          result,
          JournalOperation.removeLeadingPunctuation,
        ),
        result,
      );
    }
  });

  test('Operator spacing works across rich text and is idempotent', () {
    const op = JournalOperation.normalizeSpaces;
    for (final symbol in ['+', '-', '×', '÷', '/', '@', r'\']) {
      expect(transformJournalText('甲$symbol乙', op), '甲 $symbol 乙');
      expect(transformJournalText('a   $symbol   b', op), 'a $symbol b');
    }
    final result = transformJournalDocument([
      {
        'insert': '甲+',
        'attributes': {'bold': true},
      },
      {
        'insert': '   乙/丙\n',
        'attributes': {'italic': true},
      },
    ], op);
    expect(quill.Document.fromJson(result).toPlainText(), '甲 + 乙 / 丙\n');
    expect(result.first['attributes']['bold'], true);
    expect(transformJournalDocument(result, op), result);
  });

  testWidgets('Collection strike and fade start after task fade finishes', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = AppProvider();
    await t.runAsync(() => p.ready);
    p.addCollection('动画合集');
    final id = p.collections.single.id;
    p.addNormalTask('动画事项', collectionId: id);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    await t.pumpAndSettle();
    final tile = find.ancestor(
      of: find.text('动画事项'),
      matching: find.byType(ListTile),
    );
    await t.tap(find.byWidget(t.widget<ListTile>(tile).leading!));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.widget<Text>(find.text('动画合集')).style!.decoration, isNull);
    expect(p.normalTasks.single.isCompleted, false);
    await t.pump(const Duration(milliseconds: 30));
    expect(
      t.widget<Text>(find.text('动画合集')).style!.decoration,
      TextDecoration.lineThrough,
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(p.collections, isNotEmpty);
    await t.pump(const Duration(milliseconds: 30));
    await t.pumpAndSettle();
    expect(p.collections, isEmpty);
    expect(p.normalTasks.single.isCompleted, true);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
