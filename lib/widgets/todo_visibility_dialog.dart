import 'app_dialog.dart';
import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TodoVisibilityDialog extends StatefulWidget {
  const TodoVisibilityDialog({
    super.key,
    required this.collections,
    required this.visible,
  });
  final List<TaskCollection> collections;
  final Set<String> visible;
  @override
  State<TodoVisibilityDialog> createState() => _TodoVisibilityDialogState();
}

class _TodoVisibilityDialogState extends State<TodoVisibilityDialog> {
  late final selected = {...widget.visible};
  // Snapshot the partition so checking a row does not move it under the finger.
  late final ordered = [
    ...widget.collections.where((c) => widget.visible.contains(c.id)),
    ...widget.collections.where((c) => !widget.visible.contains(c.id)),
  ];
  void _help() => showDialog<void>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: const Text('部分显示'),
      content: const Text(
        '勾选要显示的事项合集，取消勾选可隐藏。右滑合集也可将它隐藏；回到“部分显示”重新勾选即可恢复显示。\n\n全选、全不选可快速调整，点击“确定”后生效。隐藏只改变显示，不会删除合集或其中的事项。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AppDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '部分显示',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF171717),
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: 32,
                      child: IconButton(
                        tooltip: '部分显示说明',
                        padding: EdgeInsets.zero,
                        onPressed: _help,
                        icon: const Icon(
                          Icons.error_outline,
                          size: 20,
                          color: Color(0xFF909090),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _quick(
                      '全选',
                      () => setState(
                        () => selected.addAll(
                          widget.collections.map((c) => c.id),
                        ),
                      ),
                    ),
                    _quick('全不选', () => setState(selected.clear)),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < ordered.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Color(0xFFE8E8E8),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        ordered[i].title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      value: selected.contains(ordered[i].id),
                      activeColor: const Color(0xFF171717),
                      checkColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF707070),
                        width: 1.5,
                      ),
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(ordered[i].id);
                        } else {
                          selected.remove(ordered[i].id);
                        }
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F3F5),
                    foregroundColor: const Color(0xFF606060),
                    minimumSize: const Size(76, 40),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(76, 40),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _quick(String label, VoidCallback onPressed) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF252525),
      backgroundColor: const Color(0xFFF8F8F8),
      side: const BorderSide(color: Color(0xFFE6E6E6)),
      shape: const StadiumBorder(),
      minimumSize: const Size(64, 34),
      padding: const EdgeInsets.symmetric(horizontal: 18),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}
