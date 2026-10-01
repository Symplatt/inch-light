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
            icon: const Icon(Icons.import_export_rounded),
            tooltip: '导入 / 导出数据',
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
                    subtitle: task.allDay
                        ? '${DateFormat('yyyy.MM.dd').format(task.deadline)} · 全天'
                        : DateFormat('yyyy.MM.dd  HH:mm').format(task.deadline),
                    deadline: task.deadline,
                    now: now,
                    id: task.id,
                    onDelete: () => provider.removeCountdown(task),
                    onEdit: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _CalendarEditor(provider: provider, countdown: task),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
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
                    id: task.id,
                    onDelete: () => provider.removeCycleTask(task),
                    onEdit: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _CalendarEditor(provider: provider, cycle: task),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
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
    required String id,
    required String title,
    required String subtitle,
    required DateTime deadline,
    required DateTime now,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) => Dismissible(
    key: ValueKey(id),
    direction: DismissDirection.horizontal,
    onDismissed: (_) => onDelete(),
    background: _deleteBackground(Alignment.centerLeft),
    secondaryBackground: _deleteBackground(Alignment.centerRight),
    child: Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _countdown(deadline, now)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _deleteBackground(Alignment alignment) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    alignment: alignment,
    decoration: BoxDecoration(
      color: AppColors.danger,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(Icons.delete_outline, color: Colors.white),
  );

  Widget _empty(IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Icon(icon, size: 26, color: AppColors.textGrey),
  );

  Widget _countdown(DateTime deadline, DateTime now) {
    if (!deadline.isAfter(now)) {
      return const Text(
        '已到时间',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
      );
    }
    final parts = countdownParts(deadline, now);
    return Row(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            const SizedBox(
              height: 32,
              child: VerticalDivider(
                width: 12,
                thickness: 0.5,
                color: Color(0xFFDADDE3),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${parts[i].value}',
                    style: const TextStyle(
                      fontSize: 29,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  parts[i].unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarEditor extends StatefulWidget {
  final AppProvider provider;
  final CalendarCountdown? countdown;
  final CycleTask? cycle;
  const _CalendarEditor({required this.provider, this.countdown, this.cycle});
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
  bool get _editing => widget.countdown != null || widget.cycle != null;

  @override
  void initState() {
    super.initState();
    final cycle = widget.cycle;
    final countdown = widget.countdown;
    if (cycle != null) {
      _cycle = true;
      _title.text = cycle.title;
      _allDay = cycle.allDay;
      _frequency = cycle.frequency;
      _date = cycle.time;
    } else if (countdown != null) {
      _title.text = countdown.title;
      _date = countdown.deadline;
      _allDay = countdown.allDay;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_editing ? '编辑事项' : '新建时历'),
    titleTextStyle: const TextStyle(
      fontSize: 20,
      color: AppColors.textDark,
      fontWeight: FontWeight.w400,
    ),
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
              onSelectionChanged: _editing
                  ? null
                  : (v) => setState(() => _cycle = v.first),
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
                  _allDay ? 'yyyy-MM-dd' : 'yyyy-MM-dd HH:mm',
                ).format(_date),
              ),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final picked = await showDateTimeSheet(
                  context,
                  initialDate: _date,
                  dateOnly: _allDay,
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
    final date = _allDay
        ? DateTime(_date.year, _date.month, _date.day)
        : !_cycle && _date == widget.countdown?.deadline
        ? _date
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _date.hour,
            _date.minute,
          );
    final now = DateTime.now();
    final invalidDate = _allDay
        ? date.isBefore(DateTime(now.year, now.month, now.day))
        : !date.isAfter(now);
    if (_title.text.trim().isEmpty ||
        (!_cycle && invalidDate && date != widget.countdown?.deadline)) {
      setState(
        () => _error = _title.text.trim().isEmpty ? '请输入事项名称' : '请选择未来的时间',
      );
      return;
    }
    if (widget.cycle != null) {
      widget.provider.updateCycleTask(
        widget.cycle!,
        _title.text.trim(),
        _frequency,
        date,
        allDay: _allDay,
      );
    } else if (widget.countdown != null) {
      widget.provider.updateCountdown(
        widget.countdown!,
        _title.text.trim(),
        date,
        allDay: _allDay,
      );
    } else if (_cycle) {
      widget.provider.addCycleTask(
        _title.text.trim(),
        _frequency,
        date,
        allDay: _allDay,
      );
    } else {
      widget.provider.addCountdown(_title.text.trim(), date, allDay: _allDay);
    }
    Navigator.pop(context);
  }
}
