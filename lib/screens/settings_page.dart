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
                      title: const Text('从剪贴板导入'),
                      onTap: _busy ? null : () => _readImport(file: false),
                    ),
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android)
                      ListTile(
                        leading: const Icon(Icons.file_open_outlined),
                        title: const Text('从文件导入'),
                        onTap: _busy ? null : () => _readImport(file: true),
                      ),
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
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(
                        'inch-light 文件夹中导出超过 7 天的数据文件会自动清理。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '© ${DateTime.now().year} Symplatt · 版权所有',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
