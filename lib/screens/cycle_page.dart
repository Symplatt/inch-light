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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showGlobalSettingsDialog(context, provider),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
            children: [
              if (provider.reminderError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    provider.reminderError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              _header('倒计时', countdowns.length),
              if (countdowns.isEmpty) _empty(Icons.hourglass_empty_rounded),
              for (final task in countdowns)
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(
                        task.title,
                        () => _confirmDelete(
                          context,
                          () => provider.removeCountdown(task),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('yyyy.MM.dd  HH:mm').format(task.deadline),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _countdown(task.deadline),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _header('周期', cycles.length),
              if (cycles.isEmpty) _empty(Icons.event_repeat_outlined),
              for (final task in cycles)
                _card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 62,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('MM月').format(task.nextRunTime),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd').format(task.nextRunTime),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _title(
                              task.title,
                              () => _confirmDelete(
                                context,
                                () => provider.removeCycleTask(task),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_frequencyLabels[task.frequency.index]} · ${task.allDay ? '全天' : DateFormat('HH:mm').format(task.time)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('yyyy.MM.dd').format(task.nextRunTime),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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

  Widget _header(String title, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textDark,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count',
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );

  Widget _empty(IconData icon) => _card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Icon(
          icon,
          size: 30,
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    ),
  );

  Widget _title(String title, VoidCallback onDelete) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textDark,
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          tooltip: '删除',
          onPressed: onDelete,
          icon: const Icon(
            Icons.close_rounded,
            size: 18,
            color: AppColors.textGrey,
          ),
        ),
      ),
    ],
  );

  Widget _countdown(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      return const Text('已到时间', style: TextStyle(color: AppColors.textGrey));
    }
    final values = [
      remaining.inDays,
      remaining.inHours % 24,
      remaining.inMinutes % 60,
      remaining.inSeconds % 60,
    ];
    const units = ['天', '时', '分', '秒'];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    values[i].toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  units[i],
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

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
                ButtonSegment(value: false, label: Text('倒计时')),
                ButtonSegment(value: true, label: Text('周期')),
              ],
              selected: {_cycle},
              onSelectionChanged: (v) => setState(() => _cycle = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(hintText: '事项名称'),
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
            if (_cycle)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('全天'),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                DateFormat(
                  _cycle && _allDay ? 'yyyy-MM-dd' : 'yyyy-MM-dd HH:mm',
                ).format(_date),
              ),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final picked = await showDateTimeSheet(
                  context,
                  initialDate: _date,
                  dateOnly: _cycle && _allDay,
                );
                if (picked != null && mounted) setState(() => _date = picked);
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
