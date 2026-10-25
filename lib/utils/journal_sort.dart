import 'package:lpinyin/lpinyin.dart';

enum JournalSort { edited, name }

/// Convert once per item while sorting; keep English names ahead of Han names.
class JournalNameKey implements Comparable<JournalNameKey> {
  JournalNameKey(String title) : original = title.trim().toLowerCase() {
    final first = RegExp(r'[a-z\u3400-\u9fff0-9]').firstMatch(original)?[0];
    group = first != null && RegExp(r'[\u3400-\u9fff]').hasMatch(first) ? 1 : 0;
    pinyin = PinyinHelper.getPinyinE(
      original,
      separator: '',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();
  }

  final String original;
  late final int group;
  late final String pinyin;

  @override
  int compareTo(JournalNameKey other) {
    final category = group.compareTo(other.group);
    if (category != 0) return category;
    final name = pinyin.compareTo(other.pinyin);
    return name != 0 ? name : original.compareTo(other.original);
  }
}
