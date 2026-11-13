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

  Future<void> _view(LastTimeItem item) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(item.name),
        content: Text(
          '${item.category}\n上次日期 ${_lastDateLabel(item)}\n距上次 ${item.elapsedDays(_now)} 天',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'today'),
            child: const Text('记为今天'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '共 ${items.length} 项',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final category in <String?>[
                      null,
                      ...lastTimeCategories,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
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
                      ),
                  ],
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
  @override
  void dispose() {
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
                  for (final category in lastTimeCategories)
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
