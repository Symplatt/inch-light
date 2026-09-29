import 'package:flutter/material.dart';

Future<DateTime?> showDateTimeSheet(
  BuildContext context, {
  required DateTime initialDate,
  bool dateOnly = false,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(1900),
    lastDate: DateTime(2300, 12, 31),
  );
  if (date == null || !context.mounted) return null;
  if (dateOnly) return date;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
    initialEntryMode: TimePickerEntryMode.inputOnly,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
