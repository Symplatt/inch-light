import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../models/last_time.dart';
import '../providers/app_provider.dart';
import '../utils/journal_sort.dart';
import '../widgets/app_dialog.dart';
import '../widgets/swipe_delete_card.dart';
import '../widgets/tool_edit_dialog.dart';

final _sortedLastTimeCategories =
    lastTimeCategories.where((category) => category != '其他').toList()
      ..sort((a, b) => JournalNameKey(a).compareTo(JournalNameKey(b)))
      ..add('其他');

String _lastDateLabel(LastTimeItem item) => item.startDate == null
    ? toolDateText(item.lastDate)
    : '${toolDateText(item.startDate!)} 至 ${toolDateText(item.lastDate)}';

class LastTimePage extends StatefulWidget {
  const LastTimePage({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  State<LastTimePage> createState() => _LastTimePageState();
}

class _LastTimePageState extends State<LastTimePage>
    with WidgetsBindingObserver {
  String? _category;
  DateTime _now = DateTime.now();
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDay();
  }

  void _refreshDay() {
    _dayTimer?.cancel();
    setState(() => _now = DateTime.now());
    final tomorrow = DateTime(_now.year, _now.month, _now.day + 1);
    _dayTimer = Timer(tomorrow.difference(_now), _refreshDay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  void _edit([LastTimeItem? item]) {
    showDialog<void>(
      context: context,
      builder: (_) => _LastTimeDialog(
        provider: context.read<AppProvider>(),
        item: item,
        category: _category,
      ),
    );
  }

  String _periodSummary(LastTimeItem item) {
    final overdue = item.overdueDays(_now);
    return '${item.period!.label} · ${overdue > 0 ? '已推迟 $overdue 天' : '距下次还有 ${item.remainingDays(_now)} 天'}';
  }

  Future<void> _view(LastTimeItem item) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(ctx),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '距上次',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${item.elapsedDays(_now)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const TextSpan(
                              text: ' 天',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '上次日期',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastDateLabel(item),
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (item.period != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _periodSummary(item),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 12,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        foregroundColor: AppColors.textGrey,
                        textStyle: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      onPressed: () => Navigator.pop(ctx, 'edit'),
                      child: const Text('编辑'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 48),
                        backgroundColor: AppColors.textDark,
                        textStyle: const TextStyle(fontWeight: FontWeight.w400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, 'today'),
                      child: const Text('记为今天'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      _edit(item);
    } else if (action == 'today') {
      try {
        await context.read<AppProvider>().updateLastTime(
          (data) => LastTimeData(
            items: data.items
                .map((i) => i.id == item.id ? i.doneOn(DateTime.now()) : i)
                .toList(),
          ),
        );
        if (mounted) _refreshDay();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final items =
        provider.lastTime.items
            .where((i) => _category == null || i.category == _category)
            .toList()
          ..sort((a, b) {
            final days = b.elapsedDays(_now).compareTo(a.elapsedDays(_now));
            return days == 0
                ? JournalNameKey(a.name).compareTo(JournalNameKey(b.name))
                : days;
          });
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('上一次', style: TextStyle(fontWeight: FontWeight.w400)),
        actions: [
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: '新增事项',
              onPressed: _edit,
              icon: const Icon(Icons.add),
            ),
          ),
          SizedBox(
            width:
                8 +
                (MediaQuery.sizeOf(context).width - 720).clamp(
                      0.0,
                      double.infinity,
                    ) /
                    2,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ClipRect(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 8,
                      children: [
                        for (final category in <String?>[
                          null,
                          ..._sortedLastTimeCategories,
                        ])
                          ChoiceChip(
                            label: Text(category ?? '全部'),
                            selected: _category == category,
                            showCheckmark: false,
                            selectedColor: const Color(0xFFE8EAED),
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: Color(0xFFE7E8EB)),
                            shape: const StadiumBorder(),
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无事项',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return SwipeDeleteCard(
                            key: ValueKey(item.id),
                            id: item.id,
                            bottomMargin: 8,
                            onDeleted: () => provider.updateLastTime(
                              (data) => LastTimeData(
                                items: data.items
                                    .where((i) => i.id != item.id)
                                    .toList(),
                              ),
                            ),
                            child: Material(
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: Color(0xFFE7E8EB),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _view(item),
                                onLongPress: () => _edit(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${item.category} · ${_lastDateLabel(item)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textGrey,
                                              ),
                                            ),
                                            if (item.period != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                _periodSummary(item),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      item.overdueDays(_now) > 0
                                                      ? const Color(0xFF986B5E)
                                                      : AppColors.textGrey,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${item.elapsedDays(_now)}',
                                              style: const TextStyle(
                                                fontSize: 26,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' 天',
                                              style: TextStyle(
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
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastTimeDialog extends StatefulWidget {
  const _LastTimeDialog({required this.provider, this.item, this.category});
  final AppProvider provider;
  final LastTimeItem? item;
  final String? category;
  @override
  State<_LastTimeDialog> createState() => _LastTimeDialogState();
}

class _LastTimeDialogState extends State<_LastTimeDialog> {
  late final _name = TextEditingController(text: widget.item?.name);
  late String _category = widget.item?.category ?? widget.category ?? '家务';
  late DateTime _date = widget.item?.lastDate ?? DateTime.now();
  late DateTime _start = widget.item?.startDate ?? _date;
  late bool _range = widget.item?.startDate != null;
  late LastTimePeriodType? _periodType = widget.item?.period?.type;
  late final _periodDays = TextEditingController(
    text: widget.item?.period?.type == LastTimePeriodType.days
        ? '${widget.item!.period!.value}'
        : '',
  );
  late int _weekday = widget.item?.period?.type == LastTimePeriodType.weekly
      ? widget.item!.period!.value
      : DateTime.now().weekday;
  late int _monthDay = widget.item?.period?.type == LastTimePeriodType.monthly
      ? widget.item!.period!.value
      : DateTime.now().day;

  @override
  void dispose() {
    _periodDays.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolEditDialog(
    title: widget.item == null ? '新增事项' : '编辑事项',
    fields: (enabled) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _name,
          enabled: enabled,
          decoration: toolInputDecoration('事项名称'),
          validator: requiredToolText,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: toolInputDecoration('分类'),
                items: [
                  for (final category in _sortedLastTimeCategories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: enabled ? (value) => _category = value! : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<bool>(
                initialValue: _range,
                isExpanded: true,
                decoration: toolInputDecoration('日期模式'),
                items: const [
                  DropdownMenuItem(value: false, child: Text('单个日期')),
                  DropdownMenuItem(value: true, child: Text('起止日期')),
                ],
                onChanged: enabled
                    ? (value) => setState(() => _range = value!)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final end = ToolDateField(
              key: ValueKey('end-$_range'),
              label: _range ? '结束日期' : '上次日期',
              initialDate: _date,
              lastDate: DateTime.now(),
              enabled: enabled,
              filled: true,
              onChanged: (date) => _date = date,
            );
            if (!_range) return end;
            final start = ToolDateField(
              key: const ValueKey('start'),
              label: '开始日期',
              initialDate: _start,
              lastDate: DateTime.now(),
              enabled: enabled,
              filled: true,
              onChanged: (date) => _start = date,
            );
            if (constraints.maxWidth <
                260 * MediaQuery.textScalerOf(context).scale(1)) {
              return Column(children: [start, const SizedBox(height: 12), end]);
            }
            return Row(
              children: [
                Expanded(child: start),
                const SizedBox(width: 12),
                Expanded(child: end),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ToolSelectField<String>(
          label: '预设周期（选填）',
          selectionTitle: '预设周期',
          value: _periodType?.name ?? 'none',
          items: const [
            DropdownMenuItem(value: 'none', child: Text('不设置')),
            DropdownMenuItem(value: 'days', child: Text('每几天')),
            DropdownMenuItem(value: 'weekly', child: Text('每周')),
            DropdownMenuItem(value: 'monthly', child: Text('每月')),
          ],
          onChanged: enabled
              ? (value) => setState(() {
                  _periodType = value == 'none'
                      ? null
                      : LastTimePeriodType.values.byName(value!);
                })
              : null,
        ),
        if (_periodType != null) ...[
          const SizedBox(height: 12),
          if (_periodType == LastTimePeriodType.days)
            TextFormField(
              controller: _periodDays,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: toolInputDecoration('间隔天数').copyWith(suffixText: '天'),
              validator: (value) {
                final days = int.tryParse(value?.trim() ?? '');
                return days == null || days < 1 || days > 3652059
                    ? '请输入有效的正整数天数'
                    : null;
              },
            ),
          if (_periodType == LastTimePeriodType.weekly)
            ToolSelectField<int>(
              label: '星期',
              value: _weekday,
              items: [
                for (var day = 1; day <= 7; day++)
                  DropdownMenuItem(
                    value: day,
                    child: Text(
                      '周${['一', '二', '三', '四', '五', '六', '日'][day - 1]}',
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _weekday = value!)
                  : null,
            ),
          if (_periodType == LastTimePeriodType.monthly)
            ToolSelectField<int>(
              label: '日期',
              value: _monthDay,
              items: [
                for (var day = 1; day <= 31; day++)
                  DropdownMenuItem(value: day, child: Text('$day 日')),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _monthDay = value!)
                  : null,
            ),
        ],
      ],
    ),
    save: () => widget.provider.updateLastTime((data) {
      if (_range &&
          DateUtils.dateOnly(_start).isAfter(DateUtils.dateOnly(_date))) {
        throw StateError('结束日期须不早于开始日期');
      }
      final item = LastTimeItem(
        id: widget.item?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        lastDate: DateUtils.dateOnly(_date),
        startDate: _range ? DateUtils.dateOnly(_start) : null,
        period: _periodType == null
            ? null
            : LastTimePeriod(
                type: _periodType!,
                value: switch (_periodType!) {
                  LastTimePeriodType.days => int.parse(_periodDays.text.trim()),
                  LastTimePeriodType.weekly => _weekday,
                  LastTimePeriodType.monthly => _monthDay,
                },
              ),
      );
      final items = [...data.items];
      final index = items.indexWhere((i) => i.id == item.id);
      if (index < 0) {
        items.add(item);
      } else {
        items[index] = item;
      }
      return LastTimeData(items: items);
    }),
  );
}
