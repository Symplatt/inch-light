import '../utils/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/journal_table.dart';
import '../utils/journal_markdown.dart';

List<double> journalTableWidths(
  JournalTableData data,
  double available,
  TextScaler scaler,
) {
  // Match the actual TextField letter spacing; otherwise a measured line can
  // wrap before the column receives the spare width from its neighbours.
  final char = scaler.scale(18) + .5;
  final initial = char * 5 + 16;
  final maximum = char * 10 + 16;
  final natural = List.generate(data.columns, (c) {
    var width = char + 16;
    for (var r = 0; r < data.rows.length; r++) {
      final painter = TextPainter(
        text: TextSpan(
          text: data.rows[r].cells[c],
          style: TextStyle(
            fontSize: r == 0 ? 18 : 17,
            letterSpacing: .5,
            fontWeight: r == 0 ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width + 16 > width) width = painter.width + 16;
      painter.dispose();
    }
    return width;
  });
  if (initial * data.columns > available) {
    return natural.map((w) => w.clamp(initial, maximum)).toList();
  }
  final equal = available / data.columns;
  if (natural.every((w) => w <= equal) || natural.every((w) => w >= equal)) {
    return List.filled(data.columns, equal);
  }
  // Redistribute only the spare width in short columns; total table width stays
  // fixed on screen. Once every column needs its share, use equal widths again.
  final spare = natural.fold<double>(
    0,
    (sum, w) => sum + (w < equal ? equal - w : 0),
  );
  final demand = natural.fold<double>(
    0,
    (sum, w) => sum + (w > equal ? w - equal : 0),
  );
  final transfer = demand < spare ? demand : spare;
  return natural
      .map(
        (w) => w > equal
            ? equal + transfer * (w - equal) / demand
            : equal - transfer * (equal - w) / spare,
      )
      .toList();
}

Future<JournalTableData?> showJournalTableDialog(BuildContext context) =>
    showDialog<JournalTableData>(
      context: context,
      builder: (_) => const _TableSizeDialog(),
    );

class _TableSizeDialog extends StatefulWidget {
  const _TableSizeDialog();
  @override
  State<_TableSizeDialog> createState() => _TableSizeDialogState();
}

class _TableSizeDialogState extends State<_TableSizeDialog> {
  final _rows = TextEditingController(text: '3');
  final _columns = TextEditingController(text: '2');
  String? _error;
  @override
  void dispose() {
    _rows.dispose();
    _columns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('插入表格'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('table-rows'),
          controller: _rows,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '行数（含表头）',
            helperText: '1–50 行',
          ),
        ),
        TextField(
          key: const ValueKey('table-columns'),
          controller: _columns,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '列数',
            helperText: '1–12 列，创建后固定',
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () {
          final rows = int.tryParse(_rows.text) ?? 0;
          final columns = int.tryParse(_columns.text) ?? 0;
          if (rows < 1 || rows > 50 || columns < 1 || columns > 12) {
            setState(() => _error = '请输入范围内的行数和列数');
            return;
          }
          Navigator.pop(context, JournalTableData.empty(rows, columns));
        },
        child: const Text('确定'),
      ),
    ],
  );
}

class JournalTable extends StatefulWidget {
  const JournalTable({
    super.key,
    required this.data,
    required this.onChanged,
    this.autofocus = false,
    this.readOnly = false,
    this.onDelete,
    this.onMoveDown,
  });
  final JournalTableData data;
  final ValueChanged<JournalTableData> onChanged;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveDown;
  @override
  State<JournalTable> createState() => _JournalTableState();
}

class _JournalTableState extends State<JournalTable> {
  late JournalTableData _data;
  bool _menuOpen = false;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focus = {};
  String _key(String row, int column) => '$row:$column';

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _sync();
  }

  void _sync() {
    for (final row in _data.rows) {
      for (var c = 0; c < _data.columns; c++) {
        final key = _key(row.id, c);
        final controller = _controllers.putIfAbsent(
          key,
          () => TextEditingController(text: row.cells[c]),
        );
        _focus.putIfAbsent(key, () => FocusNode()..addListener(_focusChanged));
        if (controller.text != row.cells[c]) {
          controller.value = TextEditingValue(
            text: row.cells[c],
            selection: TextSelection.collapsed(
              offset: controller.selection.extentOffset.clamp(
                0,
                row.cells[c].length,
              ),
            ),
          );
        }
      }
    }
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  bool get _headerFocused => List.generate(
    _data.columns,
    (column) => _focus[_key(_data.rows.first.id, column)]?.hasFocus ?? false,
  ).any((focused) => focused);

  @override
  void didUpdateWidget(JournalTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _data = widget.data;
    _sync();
  }

  void _newRow(String rowId, {String firstText = ''}) {
    final index = _data.rows.indexWhere((r) => r.id == rowId);
    setState(() {
      _data = _data.insertAfter(rowId, firstText: firstText);
      _sync();
    });
    final nextId = _data.rows[index + 1].id;
    widget.onChanged(_data);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus[_key(nextId, 0)]?.requestFocus();
    });
  }

  void _edit(String rowId, int column, String value) {
    final newline = value.indexOf('\n');
    if (newline >= 0) {
      _data = _data.edit(rowId, column, value.substring(0, newline));
      _newRow(
        rowId,
        firstText: value.substring(newline + 1).replaceAll('\n', ' '),
      );
    } else {
      setState(() => _data = _data.edit(rowId, column, value));
      widget.onChanged(_data);
    }
  }

  Future<void> _tableAction(String action) async {
    setState(() => _menuOpen = false);
    if (action == 'delete') {
      widget.onDelete?.call();
      return;
    }
    if (action == 'moveDown') {
      widget.onMoveDown?.call();
      return;
    }
    var message = '表格 Markdown 已复制';
    try {
      await copyText(journalTableToMarkdown(_data));
    } catch (_) {
      message = '复制失败，请重试';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focus in _focus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final widths = journalTableWidths(
        _data,
        constraints.maxWidth,
        MediaQuery.textScalerOf(context),
      );
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: widths.reduce((a, b) => a + b),
                child: Table(
                  columnWidths: {
                    for (var c = 0; c < widths.length; c++)
                      c: FixedColumnWidth(widths[c]),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder.all(color: const Color(0xFFDADDE1)),
                  children: [
                    for (var r = 0; r < _data.rows.length; r++)
                      TableRow(
                        key: ValueKey(_data.rows[r].id),
                        decoration: r == 0
                            ? const BoxDecoration(color: Color(0xFFF5F5F5))
                            : null,
                        children: [
                          for (var c = 0; c < _data.columns; c++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              child: Focus(
                                onKeyEvent: (_, event) {
                                  final controller =
                                      _controllers[_key(_data.rows[r].id, c)]!;
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter &&
                                      controller.value.composing.isCollapsed) {
                                    _newRow(_data.rows[r].id);
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  key: ValueKey(
                                    'table-cell-${_data.rows[r].id}-$c',
                                  ),
                                  readOnly: widget.readOnly,
                                  showCursor: !widget.readOnly,
                                  enableInteractiveSelection: !widget.readOnly,
                                  controller:
                                      _controllers[_key(_data.rows[r].id, c)],
                                  focusNode: _focus[_key(_data.rows[r].id, c)],
                                  autofocus:
                                      widget.autofocus && r == 0 && c == 0,
                                  textAlign: TextAlign.left,
                                  cursorHeight: r == 0 ? 18 : 17,
                                  style: TextStyle(
                                    fontSize: r == 0 ? 18 : 17,
                                    letterSpacing: .5,
                                    fontWeight: r == 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: const Color(0xFF3D3D3D),
                                    height: 1.5,
                                  ),
                                  maxLines: null,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      _edit(_data.rows[r].id, c, value),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.readOnly &&
              widget.onDelete != null &&
              (_headerFocused || _menuOpen))
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                tooltip: '表格操作',
                onOpened: () => setState(() => _menuOpen = true),
                onCanceled: () => setState(() => _menuOpen = false),
                onSelected: _tableAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'copy', child: Text('复制表格')),
                  PopupMenuItem(value: 'delete', child: Text('删除表格')),
                  PopupMenuItem(value: 'moveDown', child: Text('下移一行')),
                ],
                child: const Material(
                  elevation: 2,
                  color: Colors.white,
                  shape: CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz, size: 20),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
