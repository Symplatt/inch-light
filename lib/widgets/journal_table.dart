import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/journal_table.dart';

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
  final _columns = TextEditingController(text: '3');
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
  });
  final JournalTableData data;
  final ValueChanged<JournalTableData> onChanged;
  final bool autofocus;
  @override
  State<JournalTable> createState() => _JournalTableState();
}

class _JournalTableState extends State<JournalTable> {
  late JournalTableData _data;
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
        _focus.putIfAbsent(key, () => FocusNode());
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
      _data = _data.edit(rowId, column, value);
      widget.onChanged(_data);
    }
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
      final cellWidth = (constraints.maxWidth / _data.columns).clamp(
        110.0,
        240.0,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: cellWidth * _data.columns,
            child: Table(
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
                              controller:
                                  _controllers[_key(_data.rows[r].id, c)],
                              focusNode: _focus[_key(_data.rows[r].id, c)],
                              autofocus: widget.autofocus && r == 0 && c == 0,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: r == 0 ? 18 : 17,
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
      );
    },
  );
}
