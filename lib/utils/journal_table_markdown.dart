import '../models/journal_table.dart';

typedef MarkdownTableBlock = ({int start, int end, JournalTableData table});

List<String>? _cells(String line) {
  var text = line.trim();
  if (!text.contains('|')) return null;
  if (text.startsWith('|')) text = text.substring(1);
  if (text.endsWith('|') && !text.endsWith(r'\|')) {
    text = text.substring(0, text.length - 1);
  }
  final cells = <String>[];
  var cell = StringBuffer();
  var escaped = false;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (escaped) {
      cell.write('\\$char');
      escaped = false;
    } else if (char == r'\') {
      escaped = true;
    } else if (char == '|') {
      cells.add(cell.toString().trim());
      cell = StringBuffer();
    } else {
      cell.write(char);
    }
  }
  if (escaped) cell.write(r'\');
  cells.add(cell.toString().trim());
  return cells;
}

String _decode(String cell) => cell
    .replaceAllMapped(
      RegExp(r'(?<!\\)<br\s*/?>', caseSensitive: false),
      (_) => '\n',
    )
    .replaceAllMapped(RegExp(r'\\([\\`*_{}\[\]<>#+\-.!|~=^])'), (m) => m[1]!);

/// Only complete pipe tables are recognized; malformed rows and code fences
/// remain literal. New identifiers make every pasted table independent.
List<MarkdownTableBlock> markdownTableBlocks(String text) {
  final lines = RegExp(
    r'[^\n]*(?:\n|$)',
  ).allMatches(text).where((m) => m.start < text.length).toList();
  final result = <MarkdownTableBlock>[];
  String? fence;
  for (var i = 0; i + 1 < lines.length; i++) {
    final line = lines[i][0]!.trimRight();
    final marker = RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(line)?[1];
    if (marker != null) {
      if (fence == null) {
        fence = marker[0];
      } else if (marker.startsWith(fence)) {
        fence = null;
      }
      continue;
    }
    if (fence != null) continue;
    final header = _cells(line);
    final separator = _cells(lines[i + 1][0]!);
    if (header == null ||
        header.length > 12 ||
        separator == null ||
        separator.length != header.length ||
        !separator.every((c) => RegExp(r'^:?-{3,}:?$').hasMatch(c))) {
      continue;
    }
    final rows = <List<String>>[header];
    var end = i + 2;
    while (end < lines.length) {
      final row = _cells(lines[end][0]!);
      if (row == null || row.length != header.length) break;
      rows.add(row);
      end++;
    }
    final empty = JournalTableData.empty(rows.length, header.length);
    result.add((
      start: lines[i].start,
      end: lines[end - 1].end,
      table: JournalTableData(
        id: empty.id,
        columns: empty.columns,
        rows: List.generate(
          rows.length,
          (r) => JournalTableRow(
            id: empty.rows[r].id,
            cells: rows[r].map(_decode).toList(),
          ),
        ),
      ),
    ));
    i = end - 1;
  }
  return result;
}
