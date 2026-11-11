import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import '../models/work_log.dart';
import '../providers/app_provider.dart';
import '../widgets/app_dialog.dart';
import '../widgets/swipe_delete_card.dart';
import '../utils/journal_operations.dart';
import '../widgets/journal_export_icon.dart';

const _workLogItemFontSize = 16.0;
const _workLogHeadingFontSize = _workLogItemFontSize + 2;

class WorkLogPage extends StatefulWidget {
  const WorkLogPage({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  State<WorkLogPage> createState() => _WorkLogPageState();
}

class _WorkLogPageState extends State<WorkLogPage> with WidgetsBindingObserver {
  late DateTime _today;
  late DateTime _day;
  Timer? _dayTimer;
  double _dayDrag = 0;
  static const _volumeKeys = MethodChannel('inch_light/work_log_volume');

  Future<void> _setVolumeKeys(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _volumeKeys.invokeMethod<void>('setEnabled', enabled);
  }

  void _changeDay(int delta) {
    final next = DateTime(_day.year, _day.month, _day.day + delta);
    if (next.year < 1 || next.isAfter(_today)) return;
    setState(() => _day = next);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = workLogDay(DateTime.now());
    _day = _today;
    _scheduleDay();
    _volumeKeys.setMethodCallHandler((call) async {
      // Dialogs and pages above the log must not change the date underneath.
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (call.method == 'changeDay') _changeDay(call.arguments as int);
    });
    _setVolumeKeys(true);
  }

  void _scheduleDay() {
    _dayTimer?.cancel();
    final next = DateTime(_today.year, _today.month, _today.day + 1, 4);
    _dayTimer = Timer(next.difference(DateTime.now()), _refreshDay);
  }

  void _refreshDay() {
    final today = workLogDay(DateTime.now());
    if (today != _today) {
      setState(() {
        if (_day == _today || _day.isAfter(today)) _day = today;
        _today = today;
      });
    }
    _scheduleDay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  @override
  void dispose() {
    _volumeKeys.setMethodCallHandler(null);
    _setVolumeKeys(false);
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  void _swipeDay(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dayDrag.abs() < 40 && velocity.abs() < 300) return;
    final forward = _dayDrag.abs() >= 40 ? _dayDrag < 0 : velocity < 0;
    _changeDay(forward ? 1 : -1);
  }

  Future<void> _pickDate() async {
    var selected = _day;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('选择日期'),
        content: SizedBox(
          width: 320,
          height: 216,
          child: Localizations.override(
            context: ctx,
            delegates: const [_NumericDateDelegate()],
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              dateOrder: DatePickerDateOrder.ymd,
              initialDateTime: _day,
              minimumYear: 1,
              maximumYear: _today.year,
              maximumDate: _today,
              onDateTimeChanged: (date) => selected = date,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (mounted && picked != null) setState(() => _day = picked);
  }

  Future<void> _restore() async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('复原最近删除的事项？'),
        content: Text(
          '复原过去一分钟内删除的 ${provider.recoverableWorkLogCount} 条事项，保留原日期和栏目。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('复原'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final count = await provider.restoreRecentWorkLogItems();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count == 0 ? '可复原的事项已超过一分钟' : '已复原 $count 条事项'),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('复原失败，请重试')));
    }
  }

  Future<void> _formatText() async {
    FocusScope.of(context).unfocus();
    var changed = 0;
    try {
      await context.read<AppProvider>().updateWorkLog((data) {
        var next = data;
        final day = workLogDateKey(_day);
        for (final item in data.days[day] ?? const <WorkLogItem>[]) {
          var text = item.text;
          for (final operation in [
            JournalOperation.normalizeSpaces,
            JournalOperation.removeLeadingPunctuation,
          ]) {
            text = transformJournalText(text, operation);
          }
          text = text
              .split('\n')
              .map(
                (line) => line.trimRight().replaceAll(RegExp(r'[。．.]+$'), ''),
              )
              .join('\n')
              .trimRight();
          if (text.trim().isEmpty || text == item.text) continue;
          next = next.saveItem(
            day,
            WorkLogItem(id: item.id, columnId: item.columnId, text: text),
          );
          changed++;
        }
        return next;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changed == 0 ? '没有需要修改的内容' : '已格式化 $changed 条事项'),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('格式化失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: widget.onBack == null
          ? null
          : BackButton(onPressed: widget.onBack),
      title: OutlinedButton(
        onPressed: _pickDate,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: Color(0xFFE7E8EB)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${_day.year}年${_day.month}月${_day.day}日',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
      actions: [
        Consumer<AppProvider>(
          builder: (_, provider, _) => ValueListenableBuilder<DateTime>(
            valueListenable: provider.clock,
            builder: (_, _, _) => provider.recoverableWorkLogCount == 0
                ? const SizedBox.shrink()
                : SizedBox(
                    width: 40,
                    child: IconButton(
                      tooltip: '1分钟复原',
                      onPressed: _restore,
                      icon: const JournalActionIcon(
                        JournalActionSymbol.restore,
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: '文本格式化',
            onPressed: _formatText,
            icon: const Icon(Icons.auto_fix_high_outlined),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: '栏目设置',
            icon: const Icon(Icons.view_column_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _WorkLogColumnsDialog(),
            ),
          ),
        ),
        // Align the 24px icon boxes with the card right edge.
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dayDrag = 0,
          onHorizontalDragUpdate: (details) => _dayDrag += details.delta.dx,
          onHorizontalDragEnd: _swipeDay,
          child: Column(
            children: [
              Expanded(
                child: _WorkLogDayContent(key: ValueKey(_day), day: _day),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WorkLogDayContent extends StatelessWidget {
  const _WorkLogDayContent({super.key, required this.day});
  final DateTime day;

  Future<void> _edit(
    BuildContext context,
    WorkLogColumn column, [
    WorkLogItem? item,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => _WorkLogTextDialog(
      title: item == null ? '新增${column.name}事项' : '编辑事项',
      initial: item?.text ?? '',
      multiline: true,
      save: (text) => context.read<AppProvider>().updateWorkLog(
        (data) => data.saveItem(
          workLogDateKey(day),
          WorkLogItem(
            id: item?.id ?? const Uuid().v4(),
            columnId: column.id,
            text: text,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = context.select<AppProvider, WorkLogData>((p) => p.workLog);
    final items = data.days[workLogDateKey(day)] ?? const <WorkLogItem>[];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final column in data.columns) ...[
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: Text(
                        column.name,
                        style: const TextStyle(
                          fontSize: _workLogHeadingFontSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(12, 0),
                    child: IconButton(
                      tooltip: '新增${column.name}事项',
                      onPressed: () => _edit(context, column),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7E8EB)),
                ),
                child: Column(
                  children: [
                    if (!items.any((e) => e.columnId == column.id))
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '暂无事项',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ),
                    for (final (index, item)
                        in items
                            .where((e) => e.columnId == column.id)
                            .indexed) ...[
                      if (index > 0)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.divider,
                          indent: 16,
                          endIndent: 16,
                        ),
                      SwipeDeleteCard(
                        key: ValueKey(item.id),
                        id: item.id,
                        radius: 0,
                        bottomMargin: 0,
                        onDeleted: () async {
                          try {
                            await context.read<AppProvider>().updateWorkLog(
                              (data) =>
                                  data.removeItem(workLogDateKey(day), item.id),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('删除失败，请重试')),
                              );
                            }
                            rethrow;
                          }
                        },
                        child: Material(
                          color: AppColors.surface,
                          child: ListTile(
                            title: Text(
                              item.text,
                              style: const TextStyle(
                                fontSize: _workLogItemFontSize,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                              20,
                              4,
                              20,
                              4,
                            ),
                            onTap: () => _edit(context, column, item),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumericDateLocalizations extends DefaultCupertinoLocalizations {
  const _NumericDateLocalizations();
  @override
  String datePickerYear(int yearIndex) => '$yearIndex年';
  @override
  String datePickerMonth(int monthIndex) => '$monthIndex月';
  @override
  String datePickerStandaloneMonth(int monthIndex) => '$monthIndex月';
  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) => '$dayIndex日';
}

class _NumericDateDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _NumericDateDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const _NumericDateLocalizations());
  @override
  bool shouldReload(_NumericDateDelegate old) => false;
}

class _WorkLogColumnsDialog extends StatefulWidget {
  const _WorkLogColumnsDialog();
  @override
  State<_WorkLogColumnsDialog> createState() => _WorkLogColumnsDialogState();
}

class _WorkLogColumnsDialogState extends State<_WorkLogColumnsDialog> {
  String? _error;

  Future<bool> _update(WorkLogData Function(WorkLogData) change) async {
    try {
      await context.read<AppProvider>().updateWorkLog(change);
      if (mounted) setState(() => _error = null);
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = context
        .select<AppProvider, WorkLogData>((p) => p.workLog)
        .columns;
    return AppAlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Expanded(child: Text('栏目设置')),
          IconButton(
            tooltip: '新增栏目',
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 22),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _WorkLogTextDialog(
                title: '新增栏目',
                save: (name) => context.read<AppProvider>().updateWorkLog(
                  (data) => data.addColumn(
                    WorkLogColumn(id: const Uuid().v4(), name: name),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: columns.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final ordered = [...columns];
                  final moving = ordered.removeAt(oldIndex);
                  ordered.insert(newIndex, moving);
                  final beforeId = newIndex + 1 < ordered.length
                      ? ordered[newIndex + 1].id
                      : null;
                  _update((data) => data.moveColumn(moving.id, beforeId));
                },
                itemBuilder: (_, index) {
                  final column = columns[index];
                  return SwipeDeleteCard(
                    key: ValueKey(column.id),
                    id: column.id,
                    enabled: !column.isFixed,
                    radius: 12,
                    bottomMargin: 8,
                    onDeleted: () async {
                      if (!await _update(
                        (data) => data.removeColumn(column.id),
                      )) {
                        throw StateError('栏目删除失败');
                      }
                    },
                    child: Material(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        minTileHeight: 52,
                        contentPadding: const EdgeInsets.only(
                          left: 12,
                          right: 4,
                        ),
                        onLongPress: column.isFixed
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (_) => _WorkLogTextDialog(
                                  title: '修改栏目名称',
                                  initial: column.name,
                                  save: (name) =>
                                      context.read<AppProvider>().updateWorkLog(
                                        (data) =>
                                            data.renameColumn(column.id, name),
                                      ),
                                ),
                              ),
                        title: Text(
                          column.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Tooltip(
                                message: '拖动排序',
                                child: SizedBox(
                                  width: 40,
                                  height: 48,
                                  child: Center(
                                    child: Icon(
                                      Icons.drag_handle,
                                      size: 20,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class _WorkLogTextDialog extends StatefulWidget {
  const _WorkLogTextDialog({
    required this.title,
    required this.save,
    this.initial = '',
    this.multiline = false,
  });
  final String title;
  final String initial;
  final bool multiline;
  final Future<void> Function(String) save;

  @override
  State<_WorkLogTextDialog> createState() => _WorkLogTextDialogState();
}

class _WorkLogTextDialogState extends State<_WorkLogTextDialog> {
  late final _text = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入内容');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError ? error.message.toString() : '保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppAlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _text,
          autofocus: true,
          enabled: !_saving,
          minLines: 1,
          maxLines: widget.multiline ? 8 : 1,
          textInputAction: widget.multiline
              ? TextInputAction.newline
              : TextInputAction.done,
          onSubmitted: widget.multiline ? null : (_) => _save(),
          decoration: InputDecoration(
            hintText: widget.multiline ? '事项内容' : '栏目名称',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中' : '保存'),
        ),
      ],
    ),
  );
}
