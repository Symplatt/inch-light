import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inch_light/constants/app_colors.dart';
import 'package:inch_light/providers/app_provider.dart';
import 'package:inch_light/utils/deadline.dart';
import 'package:inch_light/widgets/deadline_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Collections with outstanding deadlines move ahead while group order is stable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider();
      await provider.ready;
      addTearDown(provider.dispose);
      for (final title in ['普通甲', '截止乙', '普通丙', '截止丁']) {
        provider.addCollection(title);
      }
      final ids = provider.collections.map((c) => c.id).toList();
      provider.addNormalTask(
        '乙事项',
        collectionId: ids[1],
        deadline: DateTime(2030),
      );
      provider.addNormalTask(
        '丁事项',
        collectionId: ids[3],
        deadline: DateTime(2020),
      );
      expect(provider.orderedCollections.map((c) => c.title), [
        '截止乙',
        '截止丁',
        '普通甲',
        '普通丙',
      ]);
      provider.toggleTaskCompletion(provider.normalTasks.first);
      expect(provider.orderedCollections.map((c) => c.title), [
        '截止丁',
        '普通甲',
        '截止乙',
        '普通丙',
      ]);
      provider.toggleTaskCompletion(provider.normalTasks.first);
      provider.updateTask(provider.normalTasks.last, '取消截止');
      expect(provider.orderedCollections.map((c) => c.title), [
        '截止乙',
        '普通甲',
        '普通丙',
        '截止丁',
      ]);
    },
  );

  test('Only green deadlines show floored days, including boundaries', () {
    final now = DateTime(2026, 10, 11, 12);
    for (final duration in [
      const Duration(seconds: -1),
      Duration.zero,
      const Duration(hours: 23),
      const Duration(hours: 24),
    ]) {
      expect(greenDeadlineDays(now.add(duration), now: now), isNull);
    }
    expect(
      greenDeadlineDays(
        now.add(const Duration(hours: 24, seconds: 1)),
        now: now,
      ),
      1,
    );
    expect(
      greenDeadlineDays(
        now.add(const Duration(hours: 47, minutes: 59)),
        now: now,
      ),
      1,
    );
    expect(greenDeadlineDays(now.add(const Duration(hours: 48)), now: now), 2);
  });

  testWidgets(
    'Deadline shows a gray hourglass and whole days on narrow screens',
    (tester) async {
      final now = DateTime(2026, 10, 11, 12);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 130,
              child: DeadlineLabel(
                deadline: now.add(const Duration(hours: 47)),
                now: now,
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      final span = text.textSpan! as TextSpan;
      expect(span.style!.color, AppColors.success);
      expect(find.text('（剩余 1 天）'), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      final number = tester.widget<Text>(find.text('1'));
      expect(number.style!.color, const Color(0xFF8D9198));
      expect(number.style!.fontWeight, FontWeight.w300);
      expect(number.style!.fontSize, 12);
      expect(span.style!.fontSize, 12);
      expect(tester.takeException(), isNull);
    },
  );
}
