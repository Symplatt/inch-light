import 'dart:convert';
import 'package:uuid/uuid.dart';

class JournalTableRow {
  const JournalTableRow({required this.id, required this.cells});
  final String id;
  final List<String> cells;
  Map<String, dynamic> toJson() => {'id': id, 'cells': cells};
}

class JournalTableData {
  const JournalTableData({
    required this.id,
    required this.columns,
    required this.rows,
  });
  final String id;
  final int columns;
  final List<JournalTableRow> rows;

  factory JournalTableData.empty(int rows, int columns) => JournalTableData(
    id: const Uuid().v4(),
    columns: columns,
    rows: List.generate(
      rows,
      (_) => JournalTableRow(
        id: const Uuid().v4(),
        cells: List.filled(columns, ''),
      ),
    ),
  );

  factory JournalTableData.decode(String encoded) {
    final data = jsonDecode(encoded) as Map;
    final columns = data['columns'] as int;
    final rawRows = data['rows'] as List;
    if (columns < 1 || columns > 12 || rawRows.isEmpty) {
      throw const FormatException('Invalid table dimensions');
    }
    final rows = rawRows.map((raw) {
      final cells = (raw['cells'] as List).cast<String>();
      if (cells.length != columns) {
        throw const FormatException('Invalid table row');
      }
      return JournalTableRow(id: raw['id'] as String, cells: cells);
    }).toList();
    if (rows.map((r) => r.id).toSet().length != rows.length) {
      throw const FormatException('Duplicate table rows');
    }
    return JournalTableData(
      id: data['id'] as String,
      columns: columns,
      rows: rows,
    );
  }

  String encode() => jsonEncode({
    'id': id,
    'columns': columns,
    'rows': rows.map((r) => r.toJson()).toList(),
  });
  String get plainText => rows.map((r) => r.cells.join(' ')).join('\n');

  JournalTableData edit(String rowId, int column, String text) =>
      JournalTableData(
        id: id,
        columns: columns,
        rows: rows.map((row) {
          if (row.id != rowId) return row;
          final cells = List<String>.from(row.cells)..[column] = text;
          return JournalTableRow(id: row.id, cells: cells);
        }).toList(),
      );

  JournalTableData insertAfter(String rowId, {String firstText = ''}) {
    final index = rows.indexWhere((r) => r.id == rowId);
    final next = List<JournalTableRow>.from(rows);
    final cells = List.filled(columns, '')..[0] = firstText;
    next.insert(
      index + 1,
      JournalTableRow(id: const Uuid().v4(), cells: cells),
    );
    return JournalTableData(id: id, columns: columns, rows: next);
  }
}
