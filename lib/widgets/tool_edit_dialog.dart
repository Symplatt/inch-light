import 'package:flutter/material.dart';
import 'app_dialog.dart';

InputDecoration toolInputDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: const Color(0xFFF3F4F6),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
  ),
);

/// Keep failed writes in the form so a retry preserves the user's input.
class ToolEditDialog extends StatefulWidget {
  const ToolEditDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.save,
  });
  final String title;
  final Widget Function(bool enabled) fields;
  final Future<void> Function() save;

  @override
  State<ToolEditDialog> createState() => _ToolEditDialogState();
}

class _ToolEditDialogState extends State<ToolEditDialog> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save();
      if (mounted) Navigator.pop(context, true);
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
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.fields(!_saving),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
      ],
    ),
  );
}

String? requiredToolText(String? value) =>
    value == null || value.trim().isEmpty ? '请填写此项' : null;

class ToolDateField extends StatefulWidget {
  const ToolDateField({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onChanged,
    this.enabled = true,
    this.lastDate,
    this.filled = false,
  });
  final String label;
  final DateTime initialDate;
  final DateTime? lastDate;
  final bool filled;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  State<ToolDateField> createState() => _ToolDateFieldState();
}

class _ToolDateFieldState extends State<ToolDateField> {
  late DateTime _date = widget.initialDate;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: !widget.enabled
        ? null
        : () async {
            final date = await showDatePicker(
              context: context,
              initialDate:
                  widget.lastDate != null && _date.isAfter(widget.lastDate!)
                  ? widget.lastDate!
                  : _date,
              firstDate: DateTime(1),
              lastDate: widget.lastDate ?? DateTime(9999, 12, 31),
            );
            if (date != null && mounted) {
              setState(() => _date = date);
              widget.onChanged(date);
            }
          },
    child: widget.filled
        ? Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF777777),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(toolDateText(_date), style: const TextStyle(fontSize: 14)),
              ],
            ),
          )
        : InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              enabled: widget.enabled,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(toolDateText(_date)),
          ),
  );
}

String toolDateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
