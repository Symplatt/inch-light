import 'package:flutter/material.dart';
import '../utils/journal_operations.dart';

String journalOperationName(JournalOperation operation) =>
    operation == JournalOperation.removeLeadingPunctuation
    ? '清理段首标点'
    : operation.label;

class JournalChainDialog extends StatefulWidget {
  const JournalChainDialog({super.key, required this.operations});
  final List<JournalOperation> operations;

  @override
  State<JournalChainDialog> createState() => _JournalChainDialogState();
}

class _JournalChainDialogState extends State<JournalChainDialog> {
  late final selected = [...widget.operations];

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('连携操作'),
    content: SizedBox(
      width: 360,
      height: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < selected.length; index++)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1}. ${journalOperationName(selected[index])}',
                    ),
                  ),
                  IconButton(
                    tooltip: '上移',
                    onPressed: index == 0
                        ? null
                        : () => setState(() {
                            final item = selected.removeAt(index);
                            selected.insert(index - 1, item);
                          }),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    tooltip: '移除',
                    onPressed: () => setState(() => selected.removeAt(index)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            const Divider(),
            for (final operation in JournalOperation.values)
              if (!selected.contains(operation))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(journalOperationName(operation)),
                  trailing: const Icon(Icons.add, size: 18),
                  onTap: () => setState(() => selected.add(operation)),
                ),
          ],
        ),
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
