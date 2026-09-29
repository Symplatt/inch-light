import 'package:flutter/cupertino.dart' show CupertinoDatePickerMode;
import '../widgets/date_time_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import '../services/reminder_service.dart';
import 'main_screen.dart';

const _frequencyLabels = ['每天', '每周', '每月', '每年'];

class CyclePage extends StatelessWidget {
  const CyclePage({super.key});
  String _remaining(DateTime deadline) {
    final d = deadline.difference(DateTime.now());
    if (d.isNegative) return '已到时间';
    return '${d.inDays}天 ${d.inHours % 24}小时 ${d.inMinutes % 60}分 ${d.inSeconds % 60}秒';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final countdowns = provider.countdowns.toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final cycles = provider.cycleTasks.toList()
      ..sort((a, b) => a.nextRunTime.compareTo(b.nextRunTime));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('时历'),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showGlobalSettingsDialog(context, provider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (provider.reminderError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                provider.reminderError!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          if (!ReminderService.supported)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('此平台可查看时历；系统提醒支持 Android 和 iOS。'),
            ),
          if (ReminderService.supported &&
              ReminderService.instance.scheduledThrough != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '离线提醒已安排至 ${DateFormat('yyyy-MM-dd').format(ReminderService.instance.scheduledThrough!)}，打开应用会自动续排。',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
          if (ReminderService.supported && !ReminderService.instance.precise)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '未开启精确闹钟权限，系统提醒可能稍有延迟。',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
          _header('倒计年月'),
          if (countdowns.isEmpty) _empty('添加未来的重要时刻，从几小时到几百天'),
          for (final task in countdowns)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(task.deadline)),
                    const SizedBox(height: 8),
                    Text(
                      _remaining(task.deadline),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: '删除倒计时',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(
                    context,
                    () => provider.removeCountdown(task),
                  ),
                ),
              ),
            ),
          const Divider(height: 32, color: Color(0xFFDDDDDD)),
          _header('时日周期'),
          if (cycles.isEmpty) _empty('记录重要日期，按周、月或年提醒'),
          for (final task in cycles)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(
                  Icons.event_repeat,
                  color: AppColors.primary,
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Text(
                  '${_frequencyLabels[task.frequency.index]} · ${task.allDay ? '全天' : DateFormat('HH:mm').format(task.time)}\n下次：${DateFormat(task.allDay ? 'yyyy-MM-dd' : 'yyyy-MM-dd HH:mm').format(task.nextRunTime)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: '删除周期',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(
                    context,
                    () => provider.removeCycleTask(task),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar-add',
        backgroundColor: AppColors.primary,
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _CalendarEditor(provider: provider),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    ),
  );
  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text, style: const TextStyle(color: AppColors.textGrey)),
  );
  void _confirmDelete(BuildContext context, VoidCallback onDelete) =>
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除此事项？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                onDelete();
                Navigator.pop(ctx);
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
}

class _CalendarEditor extends StatefulWidget {
  final AppProvider provider;
  const _CalendarEditor({required this.provider});
  @override
  State<_CalendarEditor> createState() => _CalendarEditorState();
}

class _CalendarEditorState extends State<_CalendarEditor> {
  final _title = TextEditingController();
  bool _cycle = false;
  bool _allDay = false;
  bool _saving = false;
  CycleFrequency _frequency = CycleFrequency.weekly;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新建时历'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('倒计年月')),
                ButtonSegment(value: true, label: Text('时日周期')),
              ],
              selected: {_cycle},
              onSelectionChanged: (v) => setState(() => _cycle = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '事项名称'),
              maxLength: 100,
            ),
            if (_cycle)
              DropdownButton<CycleFrequency>(
                isExpanded: true,
                value: _frequency,
                items: CycleFrequency.values
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(_frequencyLabels[f.index]),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2300),
                );
                if (picked != null && mounted) {
                  setState(
                    () => _date = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      _date.hour,
                      _date.minute,
                    ),
                  );
                }
              },
            ),
            if (_cycle)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('全天'),
                subtitle: const Text('全天事项在当日 00:00 提醒'),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
            if (!_cycle || !_allDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('时间'),
                subtitle: Text(DateFormat('HH:mm').format(_date)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showDateTimeSheet(
                    context,
                    initialDate: _date,
                    mode: CupertinoDatePickerMode.time,
                  );
                  if (picked != null && mounted) {
                    setState(
                      () => _date = DateTime(
                        _date.year,
                        _date.month,
                        _date.day,
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  }
                },
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('确定')),
    ],
  );
  Future<void> _save() async {
    final date = _cycle && _allDay
        ? DateTime(_date.year, _date.month, _date.day)
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _date.hour,
            _date.minute,
          );
    if (_title.text.trim().isEmpty ||
        (!_cycle && !date.isAfter(DateTime.now()))) {
      setState(
        () => _error = _title.text.trim().isEmpty ? '请输入事项名称' : '请选择未来的时间',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ReminderService.instance.requestPermission();
    } catch (_) {
      /* Saving remains available without notification permission. */
    }
    if (!mounted) return;
    if (_cycle) {
      widget.provider.addCycleTask(
        _title.text.trim(),
        _frequency,
        date,
        allDay: _allDay,
      );
    } else {
      widget.provider.addCountdown(_title.text.trim(), date);
    }
    Navigator.pop(context);
  }
}
