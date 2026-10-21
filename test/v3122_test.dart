import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:inch_light/utils/journal_operations.dart';

void main() {
  const op = JournalOperation.removeLeadingPunctuation;
  String plain(List<dynamic> d) => quill.Document.fromJson(d).toPlainText();
  test('Enclosed periods suppress and remove redundant outer periods', () {
    for (final pair in [
      ('（', '）'),
      ('(', ')'),
      ('“', '”'),
      ('「', '」'),
      ('『', '』'),
      ('"', '"'),
      ('【', '】'),
    ]) {
      for (final suffix in ['', '。', '。。']) {
        final text = '正文${pair.$1}内容。${pair.$2}';
        final result = transformJournalDocument([
          {'insert': '$text$suffix\n'},
        ], op);
        expect(plain(result), '$text\n');
        expect(transformJournalDocument(result, op), result);
      }
    }
    for (final text in ['正文（“内容。”）', '正文“内容。后续”', '正文（内容）。后续']) {
      final result = transformJournalDocument([
        {'insert': '$text\n'},
      ], op);
      expect(plain(result), '$text${text.endsWith('）') ? '' : '。'}\n');
    }
  });
  test('Trailing asides after sentence endings never gain an outer period', () {
    for (final mark in ['。', '？', '！', '?', '!', '.', '…']) {
      for (final pair in [
        ('（', '）'),
        ('(', ')'),
        ('“', '”'),
        ('"', '"'),
        ('「', '」'),
        ('【', '】'),
      ]) {
        for (final suffix in ['', '。', '。。', '.']) {
          final text = '正文$mark${pair.$1}说明${pair.$2}';
          final result = transformJournalDocument([
            {'insert': '$text$suffix  \n'},
          ], op);
          expect(plain(result), '$text  \n');
          expect(transformJournalDocument(result, op), result);
        }
      }
      final text = '正文（“内容$mark”）';
      expect(
        plain(
          transformJournalDocument([
            {'insert': '$text。\n'},
          ], op),
        ),
        '$text\n',
      );
    }
    for (final text in [
      '开始时间。（既可以是具体某个时分秒，也可以设置为 5 小时额度回满后立即执行）',
      '可选择任务开始时间。（既可以是具体某个时分秒，也可以设置为 5 小时额度回满后立即执行）',
      '正文！（说明（嵌套））',
      '正文？（说明“引文”）',
    ]) {
      for (final suffix in ['', '。']) {
        final result = transformJournalDocument([
          {'insert': '$text$suffix\n'},
        ], op);
        expect(plain(result), '$text\n');
        expect(transformJournalDocument(result, op), result);
      }
    }
    for (final text in [
      '前句。后句（说明）',
      '正文，（说明）',
      '正文；（说明）',
      '正文：（说明）',
      '正文。（说明）后续',
    ]) {
      expect(
        plain(
          transformJournalDocument([
            {'insert': '$text\n'},
          ], op),
        ),
        '$text。\n',
      );
    }
    final coded = [
      {
        'insert': '正文。',
        'attributes': {'code': true},
      },
      {'insert': '（说明）'},
      {'insert': '\n'},
    ];
    expect(plain(transformJournalDocument(coded, op)), '正文。（说明）。\n');
    final styled = [
      {
        'insert': '正文！',
        'attributes': {'bold': true},
      },
      {
        'insert': '（说明）。',
        'attributes': {'italic': true},
      },
      {
        'insert': '\n',
        'attributes': {'list': 'ordered'},
      },
    ];
    final result = transformJournalDocument(styled, op);
    expect(plain(result), '正文！（说明）\n');
    expect(result.first['attributes'], {'bold': true});
    expect(result[1]['attributes'], {'italic': true});
    expect(result.last['attributes'], {'list': 'ordered'});
  });
  test('Leading unclosed quotes close at paragraph end', () {
    for (final pair in [
      ('“', '”'),
      ('‘', '’'),
      ('「', '」'),
      ('『', '』'),
      ('"', '"'),
    ]) {
      final result = transformJournalDocument([
        {'insert': '  ${pair.$1}内容。\n'},
      ], op);
      expect(plain(result), '  ${pair.$1}内容。${pair.$2}\n');
      expect(transformJournalDocument(result, op), result);
    }
    final result = transformJournalDocument([
      {'insert': '“内容\n'},
    ], op);
    expect(plain(result), '“内容”。\n');
    expect(
      plain(
        transformJournalDocument([
          {'insert': '“已关闭”后续\n'},
        ], op),
      ),
      '“已关闭”后续。\n',
    );
  });
  test('Inline code and code blocks stay opaque to punctuation management', () {
    for (final text in ['，，代码', '“未闭合', '代码（内容。）。', '代码']) {
      final doc = [
        {
          'insert': text,
          'attributes': {'code': true},
        },
        {'insert': '\n'},
      ];
      expect(transformJournalDocument(doc, op), doc);
    }
    final doc = [
      {
        'insert': '，，代码',
        'attributes': {'code': true},
      },
      {
        'insert': '正文',
        'attributes': {'bold': true},
      },
      {'insert': '\n'},
    ];
    final result = transformJournalDocument(doc, op);
    expect(plain(result), '，，代码正文。\n');
    expect(result.first, doc.first);
    expect(result[1]['attributes'], {'bold': true});
    final block = [
      {'insert': '，，代码'},
      {
        'insert': '\n',
        'attributes': {'code-block': true},
      },
    ];
    expect(transformJournalDocument(block, op), block);
  });
  testWidgets('Collection names align with title in compact rows', (t) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await t.runAsync(() => provider.ready);
    await t.runAsync(() => provider.addJournalCollection('测试合集'));
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: JournalPage()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('查看合集列表'));
    await t.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    final title = find.text('合集 · 2');
    final name = find.descendant(of: dialog, matching: find.text('测试合集'));
    expect(t.getTopLeft(name).dx, t.getTopLeft(title).dx);
    final rows = find.descendant(of: dialog, matching: find.byType(ListTile));
    expect(t.getSize(rows.first).height, lessThanOrEqualTo(48));
    await t.tap(name);
    await t.pumpAndSettle();
    expect(
      provider.lastJournalCollection,
      provider.journalCollections.single.id,
    );
    await t.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
