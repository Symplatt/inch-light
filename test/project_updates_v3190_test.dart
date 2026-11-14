import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/models/journal_entry.dart';
import 'package:inch_light/models/project_updates.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/screens/project_updates_page.dart';

ProjectUpdate sample({
  String body = '第一行 空格\n第二行\t正文',
  bool completed = false,
}) => ProjectUpdate(
  id: 'sample',
  version: '测试版本',
  date: DateTime(2026, 1, 1),
  content: body,
  completed: completed,
  note: JournalEntry(
    id: 'sample',
    title: '测试版本',
    document: [
      {'insert': '$body\n'},
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 11, 14),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('旧更新缺少完成字段时保持未完成和旧日期', () {
    final update = ProjectUpdate.fromJson({
      'id': 'old',
      'version': '旧版本',
      'date': '2026-01-01T00:00:00.000',
      'content': '旧正文',
    });
    expect(update.completed, false);
    expect(update.editedAt, DateTime(2026, 1, 1));
    expect(update.content, '旧正文');
  });
  test('完成状态序列化并保留富文本和编辑日期', () {
    final update = sample().withCompleted(true);
    final restored = ProjectUpdate.fromJson(update.toJson());
    expect(restored.completed, true);
    expect(restored.note!.document, update.note!.document);
    expect(restored.editedAt, DateTime(2026, 11, 14));
    expect(restored.withCompleted(false).completed, false);
  });
  test('项目整体备份往返保留完成状态', () {
    final data = ProjectUpdatesData(
      projects: [
        UpdateProject(
          id: 'p',
          name: '测试项目',
          updates: [sample(completed: true)],
        ),
      ],
      selectedId: 'p',
    );
    final restored = ProjectUpdatesData.fromJson(data.toJson());
    expect(restored.selected!.updates.single.completed, true);
  });

  Future<AppProvider> showPage(
    WidgetTester tester, {
    String body = '第一行 空格\n第二行\t正文',
    double scale = 1,
  }) async {
    final provider = AppProvider();
    await tester.runAsync(() => provider.ready);
    await provider.updateProjectUpdates(
      (_) => ProjectUpdatesData(
        projects: [
          UpdateProject(
            id: 'p',
            name: '测试项目',
            updates: [sample(body: body)],
          ),
        ],
        selectedId: 'p',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ProjectUpdatesPage(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return provider;
  }

  testWidgets('标题日期同一行，正文删除空白最多两行，右侧按钮已移除', (tester) async {
    final provider = await showPage(tester);
    expect(
      tester.getCenter(find.text('测试版本')).dy,
      closeTo(tester.getCenter(find.text('2026-11-14')).dy, 5),
    );
    final preview = tester.widget<Text>(find.text('第一行空格第二行正文'));
    expect(preview.maxLines, 2);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(find.byTooltip('复制 Markdown'), findsNothing);
    expect(find.byTooltip('标为已完成'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('双击完成并再次双击恢复，标题删除线随状态切换', (tester) async {
    final provider = await showPage(tester);
    final card = find.text('测试版本');
    Future<void> doubleTap() async {
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(card);
      await tester.pumpAndSettle();
    }

    await doubleTap();
    expect(provider.projectUpdates.selected!.updates.single.completed, true);
    expect(
      tester.widget<Text>(card).style!.decoration,
      TextDecoration.lineThrough,
    );
    await doubleTap();
    expect(provider.projectUpdates.selected!.updates.single.completed, false);
    expect(
      tester.widget<Text>(card).style!.decoration,
      isNot(TextDecoration.lineThrough),
    );
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('长按满1秒复制完整Markdown，999毫秒不复制', (tester) async {
    final provider = await showPage(tester);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          clipboard = (call.arguments as Map)['text'] as String;
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('测试版本')),
    );
    await tester.pump(const Duration(milliseconds: 999));
    expect(clipboard, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(clipboard, contains('测试版本'));
    expect(clipboard, contains('第一行 空格'));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('空正文和大字体保持可布局', (tester) async {
    final provider = await showPage(tester, body: '', scale: 2);
    expect(find.text('测试版本'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('长正文仍只展示两行', (tester) async {
    final body = List.filled(80, '这是长正文测试').join(' ');
    final provider = await showPage(tester, body: body);
    final preview = tester.widget<Text>(find.text(body.replaceAll(' ', '')));
    expect(preview.maxLines, 2);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
