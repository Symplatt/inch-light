import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/journal_editor_page.dart';
import 'package:inch_light/screens/journal_page.dart';
import 'package:inch_light/widgets/journal_tags.dart';
import 'package:inch_light/utils/journal_markdown.dart';

JournalEntry record(
  String id,
  String title, {
  List<String> tags = const [],
  String? folder,
}) => JournalEntry(
  id: id,
  title: title,
  tags: tags,
  collectionId: folder,
  document: [
    {'insert': '正文\n'},
  ],
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 11),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Markdown exports all requested formats, escapes literal syntax and omits metadata',
    () {
      final entry = JournalEntry(
        id: 'md',
        title: '标题',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        tags: ['不导出标签'],
        document: [
          {
            'insert': '加粗',
            'attributes': {'bold': true},
          },
          {
            'insert': '倾斜',
            'attributes': {'italic': true},
          },
          {
            'insert': '删除',
            'attributes': {'strike': true},
          },
          {
            'insert': '高亮',
            'attributes': {'background': '#FFF2B3'},
          },
          {'insert': '\n'},
          for (var level = 1; level <= 3; level++) ...[
            {'insert': '标题$level'},
            {
              'insert': '\n',
              'attributes': {'header': level},
            },
          ],
          {'insert': '引用'},
          {
            'insert': '\n',
            'attributes': {'blockquote': true},
          },
          {'insert': '第一项'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': '第二项'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': '无序'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': '待选'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          {'insert': '已选'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
          {
            'insert': {'divider': 'hr'},
          },
          {'insert': '\n'},
          {'insert': '居中'},
          {
            'insert': '\n',
            'attributes': {'align': 'center'},
          },
          {'insert': '右对齐'},
          {
            'insert': '\n',
            'attributes': {'align': 'right'},
          },
          {'insert': '原始*号与==符号\n'},
        ],
      );
      final markdown = journalToMarkdown(entry);
      expect(markdown, startsWith('# 标题\n\n**加粗***倾斜*~~删除~~==高亮=='));
      expect(markdown, contains('## 标题1\n\n### 标题2\n\n#### 标题3'));
      expect(markdown, contains('> 引用'));
      expect(markdown, contains('1. 第一项\n2. 第二项'));
      expect(markdown, contains('- 无序'));
      expect(markdown, contains('- 待选\n- 已选'));
      expect(markdown, contains('\n\n---\n\n'));
      expect(markdown, contains('<div align="center">\n\n居中\n\n</div>'));
      expect(markdown, contains('<div align="right">'));
      expect(markdown, contains(r'原始\*号与\=\=符号'));
      expect(markdown, isNot(contains('不导出标签')));
    },
  );

  test(
    'Legacy records migrate and rich records, tags and collections round trip',
    () async {
      SharedPreferences.setMockInitialValues({
        'journal_entries': jsonEncode([
          {
            'id': 'legacy',
            'content': '旧记录\n下一行',
            'createdAt': '2026-09-28T10:00:00.000',
          },
        ]),
      });
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      expect(provider.journalEntries.single.content, '旧记录\n下一行');
      expect(
        provider.journalEntries.single.updatedAt,
        DateTime(2026, 9, 28, 10),
      );
      await provider.addJournalCollection('随手记');
      final folder = provider.journalCollections.single.id;
      final rich = JournalEntry(
        id: 'rich',
        title: '标题',
        tags: JournalEntry.parseTags(' 工作  日常\n工作　学习 '),
        collectionId: folder,
        document: [
          {
            'insert': '中文 👨‍👩‍👧‍👦',
            'attributes': {'bold': true, 'background': '#FFF2B3'},
          },
          {
            'insert': '\n',
            'attributes': {'header': 1, 'align': 'center'},
          },
          {
            'insert': {'divider': 'hr'},
          },
          {'insert': '\n'},
          {'insert': '事项'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
        ],
        createdAt: DateTime(2026, 10, 10),
        updatedAt: DateTime(2026, 10, 11),
      );
      await provider.saveJournalEntry(rich);
      expect(rich.wordCount, 5);
      final exported = provider.exportData();
      final restored = AppProvider();
      await restored.ready;
      addTearDown(restored.dispose);
      expect(
        restored.journalEntries.first.toJson(),
        JournalEntry.fromJson(rich.toJson()).toJson(),
      );
      expect(restored.journalCollections.single.id, folder);
      expect(await restored.importData(exported), isTrue);
      expect(restored.journalEntries.first.tags, ['工作', '日常', '学习']);
      expect(
        restored.journalEntries.first.document,
        JournalEntry.fromJson(rich.toJson()).document,
      );
      expect(await restored.importData('{"normal_tasks":[]}'), isTrue);
      expect(restored.journalEntries.length, 2);
      await restored.removeJournalEntry('rich');
      expect(restored.journalEntries.single.id, 'legacy');
    },
  );

  test(
    'Malformed rich documents cannot partially replace any backup sections',
    () async {
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      await provider.saveJournalEntry(record('safe', '保留'));
      final before = provider.exportData();
      final bad = record('bad', '错误').toJson()
        ..['document'] = [
          {'retain': 1},
        ];
      expect(
        await provider.importData(
          jsonEncode({
            'normal_tasks': [],
            'journal_entries': [bad],
          }),
        ),
        isFalse,
      );
      expect(provider.exportData(), before);
    },
  );

  test('Rapid record saves persist the newest content and time', () async {
    final provider = AppProvider();
    await provider.ready;
    addTearDown(provider.dispose);
    await Future.wait(
      List.generate(15, (i) => provider.saveJournalEntry(record('same', '$i'))),
    );
    final restored = AppProvider();
    await restored.ready;
    addTearDown(restored.dispose);
    expect(restored.journalEntries.single.title, '14');
  });

  Future<AppProvider> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> unmount(WidgetTester tester, AppProvider provider) async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  }

  testWidgets(
    'Every format control edits the document and divider leaves a writable next line',
    (tester) async {
      final provider = await mount(tester, const JournalEditorPage());
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      editor.replaceText(
        0,
        0,
        '正文',
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      await tester.pumpAndSettle();
      for (final format in [
        ('一级标题', 'header', 1),
        ('二级标题', 'header', 2),
        ('三级标题', 'header', 3),
        ('加粗', 'bold', true),
        ('引用', 'blockquote', true),
        ('有序列表', 'list', 'ordered'),
        ('无序列表', 'list', 'bullet'),
        ('倾斜', 'italic', true),
        ('删除线', 'strike', true),
        ('高亮', 'background', '#FFF2B3'),
        ('居中对齐', 'align', 'center'),
        ('左对齐', 'align', 'left'),
        ('右对齐', 'align', 'right'),
      ]) {
        editor.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
          quill.ChangeSource.local,
        );
        final button = find.byKey(ValueKey('format-${format.$1}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(
          editor.getSelectionStyle().attributes[format.$2]?.value,
          format.$3,
          reason: format.$1,
        );
      }
      editor.updateSelection(
        TextSelection.collapsed(offset: editor.document.length - 1),
        quill.ChangeSource.local,
      );
      final divider = find.byKey(const ValueKey('format-分隔线'));
      await tester.ensureVisible(divider);
      await tester.tap(divider);
      await tester.pump();
      editor.replaceText(editor.selection.start, 0, '后续', null);
      await tester.pump();
      final delta = editor.document.toDelta().toJson();
      final embedIndex = delta.indexWhere((op) => op['insert'] is Map);
      expect(embedIndex, greaterThanOrEqualTo(0));
      expect(
        delta.skip(embedIndex + 1).map((op) => op['insert']).join(),
        contains('\n后续'),
      );
      expect(tester.takeException(), isNull);
      await unmount(tester, provider);
    },
  );

  testWidgets('Send offers Markdown and long image export', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': copied};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final entry = JournalEntry(
      id: 'copy',
      title: '笔记',
      document: [
        {
          'insert': '高亮',
          'attributes': {'background': '#FFF2B3'},
        },
        {'insert': '\n'},
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final provider = await mount(tester, JournalEditorPage(entry: entry));
    await tester.tap(find.byTooltip('导出'));
    await tester.pumpAndSettle();
    expect(find.text('导出长图'), findsOneWidget);
    await tester.tap(find.text('复制 Markdown'));
    await tester.pump();
    expect(copied, '# 笔记\n\n==高亮==');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Markdown 已复制'), findsOneWidget);
    await unmount(tester, provider);
  });

  testWidgets(
    'Title and tag search share one query and include collection records',
    (tester) async {
      final provider = await mount(tester, const JournalPage());
      final setup = () async {
        await provider.addJournalCollection('合集');
        final folder = provider.journalCollections.single.id;
        await provider.saveJournalEntry(record('1', '旅行计划'));
        await provider.saveJournalEntry(
          record('2', '周末', tags: ['旅行'], folder: folder),
        );
        await provider.saveJournalEntry(record('3', '其他'));
      }();
      await tester.pumpAndSettle();
      await setup;
      await tester.pumpAndSettle();
      expect(find.text('周末'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('record-search')), '旅行');
      await tester.pumpAndSettle();
      expect(find.text('旅行计划'), findsOneWidget);
      expect(find.text('周末'), findsOneWidget);
      expect(find.text('其他'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('record-search')), '正文');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的记录'), findsOneWidget);
      await unmount(tester, provider);
    },
  );

  testWidgets(
    'Keyboard switches actions, toolbar fits seven slots, rich text and title undo/redo save',
    (tester) async {
      final provider = await mount(tester, const JournalEditorPage());
      expect(find.byTooltip('标签'), findsOneWidget);
      expect(find.byTooltip('撤回'), findsNothing);
      expect(find.byType(JournalTags), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.byKey(const ValueKey('record-title')));
      await tester.enterText(
        find.byKey(const ValueKey('record-title')),
        '我的记录',
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('标签'), findsOneWidget);
      expect(find.byTooltip('取消撤回'), findsOneWidget);
      await tester.tap(find.byTooltip('撤回'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('record-title')))
            .controller!
            .text,
        '',
      );
      await tester.tap(find.byTooltip('取消撤回'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('record-title')))
            .controller!
            .text,
        '我的记录',
      );
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      editor.replaceText(
        0,
        0,
        '测试正文',
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );
      await tester.pump();
      final first = tester.getRect(find.byKey(const ValueKey('format-一级标题')));
      final seventh = tester.getRect(find.byKey(const ValueKey('format-无序列表')));
      expect(first.left, 0);
      expect(seventh.right, closeTo(390, .01));
      expect(first.width, closeTo(390 / 7, .01));
      tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .focusNode
          .requestFocus();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('format-加粗')));
      await tester.pump();
      expect(editor.getSelectionStyle().attributes['bold']?.value, true);
      await tester.tap(find.byTooltip('撤回'));
      await tester.pump();
      expect(editor.document.toDelta().toJson().first['attributes'], isNull);
      await tester.tap(find.byTooltip('取消撤回'));
      await tester.pump();
      expect(editor.document.toDelta().toJson().first['attributes'], {
        'bold': true,
      });
      await tester.drag(
        find.byKey(const ValueKey('record-format-scroll')),
        const Offset(-650, 0),
      );
      await tester.pumpAndSettle();
      final left = tester.widget<IconButton>(
        find.byKey(const ValueKey('format-左对齐')),
      );
      expect(left.style!.backgroundColor!.resolve({}), const Color(0xFFEDEDED));
      await tester.tap(find.byKey(const ValueKey('format-居中对齐')));
      await tester.pump();
      expect(editor.getSelectionStyle().attributes['align']?.value, 'center');
      await tester.tap(find.byTooltip('确定'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      expect(provider.journalEntries.single.title, '我的记录');
      expect(provider.journalEntries.single.wordCount, 4);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(find.byTooltip('标签'), findsOneWidget);
      expect(find.byType(JournalFormatBar), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester, provider);
    },
  );

  testWidgets(
    'Tag dialog deduplicates whitespace-separated tags and positions chips above body',
    (tester) async {
      final provider = await mount(tester, const JournalEditorPage());
      await tester.tap(find.byTooltip('标签'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, ' 日常 工作 日常　学习 ');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(provider.journalEntries.single.tags, ['日常', '工作', '学习']);
      expect(find.byType(JournalTags), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(JournalTags)).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const ValueKey('record-metadata')))
              .dy,
        ),
      );
      expect(
        tester.getBottomLeft(find.byType(JournalTags)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(quill.QuillEditor)).dy),
      );
      await unmount(tester, provider);
    },
  );

  testWidgets(
    'New record from collection retains membership and blank visit creates nothing',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'journal_collections': jsonEncode([
          {'id': 'folder', 'title': '合集', 'updatedAt': null},
        ]),
      });
      final provider = await mount(
        tester,
        const JournalPage(collectionId: 'folder'),
      );
      await tester.tap(find.byTooltip('新建记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(provider.journalEntries, isEmpty);
      await tester.tap(find.byTooltip('新建记录'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-title')),
        '合集笔记',
      );
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(provider.journalEntries.single.collectionId, 'folder');
      expect(find.text('合集笔记'), findsOneWidget);
      await unmount(tester, provider);
    },
  );
}
