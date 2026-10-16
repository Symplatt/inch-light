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
    this.headerBold = true,
  });
  final String id;
  final bool headerBold;
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
      headerBold: data['headerBold'] as bool? ?? true,
      columns: columns,
      rows: rows,
    );
  }

  String encode() => jsonEncode({
    'id': id,
    'columns': columns,
    if (!headerBold) 'headerBold': false,
    'rows': rows.map((r) => r.toJson()).toList(),
  });
  String get plainText => rows.map((r) => r.cells.join(' ')).join('\n');

  JournalTableData edit(String rowId, int column, String text) =>
      JournalTableData(
        id: id,
        headerBold: headerBold,
        columns: columns,
        rows: rows.map((row) {
          if (row.id != rowId) return row;
          final cells = List<String>.from(row.cells)..[column] = text;
          return JournalTableRow(id: row.id, cells: cells);
        }).toList(),
      );

  JournalTableData withoutBold() =>
      JournalTableData(id: id, columns: columns, rows: rows, headerBold: false);

  // The final row is kept empty so the embed always remains decodable.
  JournalTableData removeRow(String rowId) => JournalTableData(
    id: id,
    headerBold: headerBold,
    columns: columns,
    rows: rows.length == 1
        ? [JournalTableRow(id: rows.first.id, cells: List.filled(columns, ''))]
        : rows.where((row) => row.id != rowId).toList(),
  );

  JournalTableData removeColumn(int column) {
    if (column < 0 || column >= columns || columns == 1) return this;
    return JournalTableData(
      id: id,
      columns: columns - 1,
      headerBold: headerBold,
      rows: rows
          .map(
            (row) => JournalTableRow(
              id: row.id,
              cells: List<String>.from(row.cells)..removeAt(column),
            ),
          )
          .toList(),
    );
  }

  JournalTableData insertColumnAfter(int column) {
    if (column < 0 || column >= columns || columns >= 12) return this;
    return JournalTableData(
      id: id,
      headerBold: headerBold,
      columns: columns + 1,
      rows: rows
          .map(
            (row) => JournalTableRow(
              id: row.id,
              cells: List<String>.from(row.cells)..insert(column + 1, ''),
            ),
          )
          .toList(),
    );
  }

  JournalTableData insertAfter(String rowId, {String firstText = ''}) {
    final index = rows.indexWhere((r) => r.id == rowId);
    final next = List<JournalTableRow>.from(rows);
    final cells = List.filled(columns, '')..[0] = firstText;
    next.insert(
      index + 1,
      JournalTableRow(id: const Uuid().v4(), cells: cells),
    );
    return JournalTableData(
      id: id,
      columns: columns,
      rows: next,
      headerBold: headerBold,
    );
  }
}
