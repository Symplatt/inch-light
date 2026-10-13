import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class JournalDialogFrame extends StatelessWidget {
  const JournalDialogFrame({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Dialog(
    elevation: 0,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class JournalCollectionDialog extends StatefulWidget {
  const JournalCollectionDialog({super.key, this.title});
  final String? title;
  @override
  State<JournalCollectionDialog> createState() =>
      _JournalCollectionDialogState();
}

class _JournalCollectionDialogState extends State<JournalCollectionDialog> {
  late final _input = TextEditingController(text: widget.title ?? '');
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _save() {
    if (_input.text.trim().isNotEmpty) {
      Navigator.pop(context, _input.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => JournalDialogFrame(
    title: widget.title == null ? '新建合集' : '编辑合集',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _input,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F6F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB8BDC4)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            if (widget.title != null)
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ''),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除合集'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _input.text.trim().isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(88, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    ),
  );
}

class JournalDeleteCollectionDialog extends StatelessWidget {
  const JournalDeleteCollectionDialog({
    super.key,
    required this.title,
    required this.count,
  });
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) {
    Widget choice({
      required String label,
      required String detail,
      required IconData icon,
      required bool delete,
    }) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: delete ? const Color(0xFFFAF4F3) : const Color(0xFFF5F6F7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, delete),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: delete ? AppColors.danger : AppColors.textGrey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: delete ? AppColors.danger : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return JournalDialogFrame(
      title: '删除合集',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '“$title” · $count 篇笔记',
            style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
          const SizedBox(height: 4),
          choice(
            label: '保留笔记，删除合集',
            detail: '笔记移入默认合集',
            icon: Icons.drive_file_move_outline,
            delete: false,
          ),
          choice(
            label: '删除合集和笔记',
            detail: '同时删除其中的笔记，无法恢复',
            icon: Icons.delete_outline,
            delete: true,
          ),
        ],
      ),
    );
  }
}
