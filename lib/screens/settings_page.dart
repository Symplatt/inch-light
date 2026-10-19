import '../constants/app_usage_guide.dart';
import '../utils/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../widgets/section_heading.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _pendingImport;
  bool _busy = false;

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
    final data = provider.exportData();
    try {
      await copyText(data);
    } catch (_) {
      if (context.mounted) _showMessage(context, '复制失败，请重试');
      return;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (context.mounted) _showMessage(context, '数据已复制');
      return;
    }
    try {
      final path = await const MethodChannel(
        'inch_light/data_export',
      ).invokeMethod<String>('exportData', {'data': data});
      if (context.mounted) {
        _showMessage(context, path == null ? '已复制；文件未保存，请重试' : '已复制并保存到 $path');
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        _showMessage(context, '已复制；${error.message ?? '文件未保存，请重试'}');
      }
    } catch (_) {
      if (context.mounted) _showMessage(context, '已复制；文件未保存，请重试');
    }
  }

  Future<void> _readImport({required bool file}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pendingImport = null;
    });
    try {
      final text = file
          ? await const MethodChannel(
              'inch_light/data_export',
            ).invokeMethod<String>('importFile')
          : (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        if (!file) _showMessage(context, '剪贴板为空');
      } else {
        setState(() => _pendingImport = text);
      }
    } catch (_) {
      if (mounted) _showMessage(context, file ? '文件读取失败，请重试' : '剪贴板读取失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport(AppProvider provider) async {
    final text = _pendingImport;
    if (text == null || _busy) return;
    setState(() => _busy = true);
    try {
      final success = await provider.importData(text);
      if (mounted) {
        setState(() => _pendingImport = null);
        _showMessage(context, success ? '导入成功' : '数据格式错误');
      }
    } catch (_) {
      if (mounted) _showMessage(context, '导入失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dataAction(
    IconData icon,
    String label,
    String description,
    VoidCallback action,
  ) => ListTile(
    enabled: !_busy,
    onTap: action,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    leading: Icon(icon, size: 26, color: AppColors.textDark),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w400)),
    subtitle: Text(
      description,
      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
    ),
  );

  Widget _dataDivider() => const Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: Color(0xFFEEF0F3),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('设置'),
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          IconButton(
            tooltip: '软件信息',
            icon: const Icon(Icons.help_outline, color: AppColors.textGrey),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('一日千录'),
                content: const SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '版本 3.12.1（构建 54）',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                        SizedBox(height: 16),
                        Text('版权所有 © Symplatt'),
                        SizedBox(height: 16),
                        Text('数据保存在本机，可在设置中导出备份。'),
                        SizedBox(height: 16),
                        Text(appUsageGuide),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => showLicensePage(
                      context: dialogContext,
                      applicationName: '一日千录',
                      applicationVersion: '3.12.1',
                      applicationLegalese: '版权所有 © Symplatt',
                    ),
                    child: const Text('开源许可'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                  side: const BorderSide(color: Color(0xFFE7E8EB)),
                ),
                child: RadioGroup<bool>(
                  groupValue: provider.looseTasksFirst,
                  onChanged: (value) {
                    if (value != null) provider.setLooseTasksFirst(value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<bool>(value: false, title: Text('事项合集在上')),
                      RadioListTile<bool>(value: true, title: Text('零散事项在上')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(title: '时历顺序'),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7E8EB)),
                ),
                child: RadioGroup<bool>(
                  groupValue: provider.countdownsFirst,
                  onChanged: (value) {
                    if (value != null) provider.setCountdownsFirst(value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<bool>(value: true, title: Text('倒计时在上')),
                      RadioListTile<bool>(value: false, title: Text('周期在上')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(title: '数据管理'),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7E8EB)),
                ),
                child: Column(
                  children: [
                    _dataAction(
                      Icons.save_alt_outlined,
                      '导出备份',
                      '导出全部数据到本地',
                      () => _exportData(context, provider),
                    ),
                    _dataDivider(),
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android) ...[
                      _dataAction(
                        Icons.insert_drive_file_outlined,
                        '文件导入',
                        '从备份文件恢复数据',
                        () => _readImport(file: true),
                      ),
                      _dataDivider(),
                    ],
                    _dataAction(
                      Icons.content_paste_outlined,
                      '粘贴导入',
                      '从剪贴板文本导入数据',
                      () => _readImport(file: false),
                    ),
                    _dataDivider(),
                    if (_pendingImport != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('将覆盖备份中包含的数据，请先导出当前数据。'),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _pendingImport = null,
                                        ),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _confirmImport(provider),
                                  child: const Text(
                                    '确认导入',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '导出的本地备份文件将在 7 天后自动删除',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
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
