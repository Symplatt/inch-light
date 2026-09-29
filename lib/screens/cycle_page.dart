import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import '../utils/countdown.dart';
import '../widgets/date_time_sheet.dart';
import 'main_screen.dart';

const _frequencyLabels = ['每天', '每周', '每月', '每年'];

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});
  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  bool _countdownsExpanded = true;
  bool _cyclesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final countdowns = provider.countdowns.toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final cycles = provider.cycleTasks.toList()
      ..sort((a, b) => a.nextRunTime.compareTo(b.nextRunTime));
    final now = DateTime.now();
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              _header(
                '倒计时',
                countdowns.length,
                _countdownsExpanded,
                () =>
                    setState(() => _countdownsExpanded = !_countdownsExpanded),
              ),
              if (_countdownsExpanded) ...[
                if (countdowns.isEmpty) _empty(Icons.hourglass_empty_rounded),
                for (final task in countdowns)
                  _card(
                    title: task.title,
                    subtitle: DateFormat(
                      'yyyy.MM.dd  HH:mm',
                    ).format(task.deadline),
                    deadline: task.deadline,
                    now: now,
                    onDelete: () => _confirmDelete(
                      context,
                      () => provider.removeCountdown(task),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              _header(
                '周期',
                cycles.length,
                _cyclesExpanded,
                () => setState(() => _cyclesExpanded = !_cyclesExpanded),
              ),
              if (_cyclesExpanded) ...[
                if (cycles.isEmpty) _empty(Icons.event_repeat_outlined),
                for (final task in cycles)
                  _card(
                    title: task.title,
                    subtitle:
                        '${_frequencyLabels[task.frequency.index]} · ${task.allDay ? '全天' : DateFormat('HH:mm').format(task.time)} · 下次 ${DateFormat('yyyy.MM.dd').format(task.nextRunTime)}',
                    deadline: task.nextRunTime,
                    now: now,
                    onDelete: () => _confirmDelete(
                      context,
                      () => provider.removeCycleTask(task),
                    ),
                  ),
              ],
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

  Widget _header(
    String title,
    int count,
    bool expanded,
    VoidCallback onTap,
  ) => Semantics(
    button: true,
    expanded: expanded,
    child: InkWell(
      key: ValueKey('section-$title'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const Spacer(),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 22),
          ],
        ),
      ),
    ),
  );

  Widget _card({
    required String title,
    required String subtitle,
    required DateTime deadline,
    required DateTime now,
    required VoidCallback onDelete,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            IconButton(
              tooltip: '删除$title',
              onPressed: onDelete,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _countdown(deadline, now),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    ),
  );

  Widget _empty(IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Icon(icon, size: 26, color: AppColors.textGrey),
  );

  Widget _countdown(DateTime deadline, DateTime now) {
    if (!deadline.isAfter(now)) {
      return const Text(
        '已到时间',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      );
    }
    final parts = countdownParts(deadline, now);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Text(
              '${parts[i].value}',
              style: const TextStyle(
                fontSize: 28,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                parts[i].unit,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: AppColors.textGrey,
                ),
              ),
            ),
          ],
        ],
      ),
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
      FilledButton(onPressed: _save, child: const Text('确定')),
    ],
  );
  void _save() {
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
