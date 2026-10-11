import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../widgets/section_heading.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  Future<void> _exportData(BuildContext context, AppProvider provider) async {
    await Clipboard.setData(ClipboardData(text: provider.exportData()));
    if (context.mounted) _showMessage(context, '数据已复制');
  }

  Future<void> _importData(BuildContext context, AppProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _showMessage(context, '剪贴板为空');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认覆盖？'),
        content: const Text('将覆盖备份中包含的数据，请先导出当前数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '确认导入',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await provider.importData(text);
    if (context.mounted) {
      _showMessage(context, success ? '导入成功' : '数据格式错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              const SectionHeading(title: '事项顺序'),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: RadioGroup<bool>(
                  groupValue: provider.looseTasksFirst,
                  onChanged: (value) {
                    if (value != null) provider.setLooseTasksFirst(value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<bool>(value: true, title: Text('零散事项在上')),
                      RadioListTile<bool>(value: false, title: Text('事项合集在上')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(title: '笔记顺序'),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: RadioGroup<bool>(
                  groupValue: provider.looseNotesFirst,
                  onChanged: (value) {
                    if (value != null) provider.setLooseNotesFirst(value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<bool>(value: true, title: Text('零散笔记在上')),
                      RadioListTile<bool>(value: false, title: Text('笔记合集在上')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(title: '数据'),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.copy_all_outlined),
                      title: const Text('导出数据'),
                      onTap: () => _exportData(context, provider),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.content_paste_go_outlined),
                      title: const Text('导入数据'),
                      onTap: () => _importData(context, provider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
