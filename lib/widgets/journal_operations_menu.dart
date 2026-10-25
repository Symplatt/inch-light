import 'package:flutter/material.dart';
import '../utils/journal_operations.dart';
import 'journal_format_icon.dart';

List<PopupMenuEntry<JournalOperation>> journalOperationsMenu(
  BuildContext context, {
  required VoidCallback runChain,
  required VoidCallback editChain,
  required Set<JournalOperation> available,
}) {
  void closeThen(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  PopupMenuItem<JournalOperation> group(String label) => PopupMenuItem(
    enabled: false,
    height: 24,
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, color: Color(0xFF909090)),
    ),
  );
  Widget icon(JournalOperation operation) => switch (operation) {
    JournalOperation.clearBlankLines => const Icon(
      Icons.format_clear,
      size: 20,
    ),
    JournalOperation.normalizeSpaces => const Icon(Icons.space_bar, size: 20),
    JournalOperation.removeLeadingPunctuation => const Icon(
      Icons.filter_alt_outlined,
      size: 20,
    ),
    JournalOperation.shuffleBullets => const Icon(
      Icons.format_list_bulleted,
      size: 20,
    ),
    JournalOperation.removeBold => const JournalFormatIcon(
      JournalFormatSymbol.boldWide,
    ),
    JournalOperation.promoteHeadings => const JournalFormatIcon(
      JournalFormatSymbol.headingUp,
    ),
    JournalOperation.demoteHeadings => const JournalFormatIcon(
      JournalFormatSymbol.headingDown,
    ),
    JournalOperation.capitalize => const Icon(Icons.text_fields, size: 20),
    JournalOperation.addSentencePeriods => const Icon(
      Icons.more_horiz,
      size: 20,
    ),
    JournalOperation.checkAll => const Icon(Icons.check_box_outlined, size: 20),
    JournalOperation.uncheckAll => const Icon(
      Icons.indeterminate_check_box_outlined,
      size: 20,
    ),
  };
  PopupMenuItem<JournalOperation> item(JournalOperation operation) =>
      PopupMenuItem(
        value: operation,
        height: 40,
        child: Row(
          children: [
            IconTheme(
              data: const IconThemeData(color: Color(0xFF606060)),
              child: SizedBox.square(dimension: 22, child: icon(operation)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                operation.label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF252525)),
              ),
            ),
          ],
        ),
      );
  return [
    PopupMenuItem<JournalOperation>(
      enabled: false,
      height: 36,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '快捷操作',
              style: TextStyle(fontSize: 16, color: Color(0xFF252525)),
            ),
          ),
          SizedBox.square(
            dimension: 32,
            child: IconButton(
              tooltip: '功能介绍',
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.error_outline,
                size: 20,
                color: Color(0xFF808080),
              ),
              onPressed: () => closeThen(() {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('快捷操作'),
                    content: const Text(
                      '文本整理：管理标点、整理空格、清除空行或打乱无序列表。\n\n'
                      '格式调整：升降标题、取消加粗或将首字母大写。\n\n'
                      '选框操作：勾选全部或清空勾选。\n\n'
                      '连携操作：按设定顺序一次执行多项操作，点击铅笔编辑。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('知道了'),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    ),
    const PopupMenuDivider(height: 9, color: Color(0xFFDDDDDD)),
    group('文本整理'),
    for (final operation in [
      JournalOperation.removeLeadingPunctuation,
      JournalOperation.normalizeSpaces,
      JournalOperation.clearBlankLines,
      JournalOperation.shuffleBullets,
    ])
      if (available.contains(operation)) item(operation),
    if ([
      JournalOperation.promoteHeadings,
      JournalOperation.demoteHeadings,
      JournalOperation.removeBold,
      JournalOperation.capitalize,
    ].any(available.contains)) ...[
      const PopupMenuDivider(
        height: 9,
        thickness: 0.5,
        color: Color(0xFFF2F2F2),
      ),
      group('格式调整'),
      for (final operation in [
        JournalOperation.promoteHeadings,
        JournalOperation.demoteHeadings,
        JournalOperation.removeBold,
        JournalOperation.capitalize,
      ])
        if (available.contains(operation)) item(operation),
    ],
    if (available.contains(JournalOperation.checkAll)) ...[
      const PopupMenuDivider(
        height: 9,
        thickness: 0.5,
        color: Color(0xFFF2F2F2),
      ),
      group('选框操作'),
      item(JournalOperation.checkAll),
      item(JournalOperation.uncheckAll),
    ],
    const PopupMenuDivider(height: 9, thickness: 0.5, color: Color(0xFFF2F2F2)),
    PopupMenuItem<JournalOperation>(
      enabled: false,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF252525),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () => closeThen(runChain),
              icon: const Icon(Icons.account_tree_outlined, size: 20),
              label: const Text('连携操作', style: TextStyle(fontSize: 15)),
            ),
          ),
          SizedBox.square(
            dimension: 36,
            child: IconButton(
              tooltip: '编辑连携操作',
              padding: EdgeInsets.zero,
              onPressed: () => closeThen(editChain),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ),
        ],
      ),
    ),
  ];
}
