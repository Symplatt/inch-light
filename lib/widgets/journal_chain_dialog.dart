import 'package:flutter/material.dart';
import '../utils/journal_operations.dart';

String journalOperationName(JournalOperation operation) => operation.label;

class JournalChainDialog extends StatefulWidget {
  const JournalChainDialog({super.key, required this.operations});
  final List<JournalOperation> operations;

  @override
  State<JournalChainDialog> createState() => _JournalChainDialogState();
}

class _JournalChainDialogState extends State<JournalChainDialog> {
  late final List<JournalOperation?> items = [
    ...normalizeJournalOperations(widget.operations),
    null,
    ...JournalOperation.values.where(
      (op) =>
          op != JournalOperation.addSentencePeriods &&
          !normalizeJournalOperations(widget.operations).contains(op),
    ),
  ];

  List<JournalOperation> get selected =>
      items.takeWhile((item) => item != null).cast<JournalOperation>().toList();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('连携操作'),
    content: SizedBox(
      width: 360,
      height: 460,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        header: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '已选中 · 长按整行拖动选择与排序',
            style: TextStyle(fontSize: 12, color: Color(0xFF808080)),
          ),
        ),
        itemCount: items.length,
        onReorderItem: (oldIndex, newIndex) {
          if (items[oldIndex] == null) return;
          setState(() {
            final operation = items.removeAt(oldIndex);
            items.insert(newIndex, operation);
          });
        },
        itemBuilder: (context, index) {
          final operation = items[index];
          if (operation == null) {
            return const SizedBox(
              key: ValueKey('chain-unselected-divider'),
              height: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(thickness: 0.5, color: Color(0xFFE8E8E8)),
                  Text(
                    '未选中',
                    style: TextStyle(fontSize: 12, color: Color(0xFF808080)),
                  ),
                ],
              ),
            );
          }
          final isSelected = index < items.indexOf(null);
          return ReorderableDelayedDragStartListener(
            key: ValueKey(operation),
            index: index,
            child: Container(
              color: Colors.transparent,
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      isSelected ? '${index + 1}.' : '•',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      journalOperationName(operation),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, selected),
        child: const Text('保存'),
      ),
    ],
  );
}
