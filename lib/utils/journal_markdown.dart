import '../models/journal_entry.dart';
import '../models/journal_table.dart';

String _escape(String text) => text.replaceAllMapped(
  RegExp(r'[\\`*_{}\[\]<>#+\-.!|~=]'),
  (match) => '\\${match[0]}',
);

String _inline(String text, Map attributes) {
  if (text.trim().isEmpty) return text;
  // Keep edge whitespace outside delimiters so emphasis remains valid Markdown.
  final leading = RegExp(r'^\s*').stringMatch(text)!;
  final trailing = RegExp(r'\s*$').stringMatch(text)!;
  var value = _escape(text.trim());
  if (attributes['italic'] == true) value = '*$value*';
  if (attributes['bold'] == true) value = '**$value**';
  if (attributes['strike'] == true) value = '~~$value~~';
  if (attributes['background'] != null) value = '==$value==';
  return '$leading$value$trailing';
}

/// Exports the title and body, leaving dates, counts and organizational tags out
/// of the user's prose. Alignment uses HTML because Markdown has no equivalent.
String journalToMarkdown(JournalEntry entry) {
  final lines = <({String text, String kind})>[];
  var current = StringBuffer();
  var ordered = 0;
  void finish(Map attributes) {
    var text = current.toString();
    current = StringBuffer();
    var kind = 'paragraph';
    if (attributes['list'] != 'ordered') ordered = 0;
    final header = attributes['header'];
    if (header is int) {
      text = '${'#' * (header + 1).clamp(2, 6)} $text';
      kind = 'heading';
    } else if (attributes['blockquote'] == true) {
      text = '> $text';
      kind = 'quote';
    } else {
      switch (attributes['list']) {
        case 'ordered':
          text = '${++ordered}. $text';
          kind = 'ordered';
        case 'bullet':
          text = '- $text';
          kind = 'bullet';
        case 'checked':
          text = '- [x] $text';
          kind = 'check';
        case 'unchecked':
          text = '- [ ] $text';
          kind = 'check';
      }
    }
    final align = attributes['align'];
    if (align == 'center' || align == 'right') {
      text = '<div align="$align">\n\n$text\n\n</div>';
      kind = 'html';
    }
    lines.add((text: text, kind: kind));
  }

  for (final op in entry.document) {
    final attributes = op['attributes'] as Map? ?? {};
    final insert = op['insert'];
    if (insert is Map) {
      if (insert['table'] is String) {
        final table = JournalTableData.decode(insert['table']);
        String row(List<String> cells) =>
            '| ${cells.map((cell) => _escape(cell).replaceAll('\n', '<br>')).join(' | ')} |';
        current.write(
          [
            row(table.rows.first.cells),
            '| ${List.filled(table.columns, ':---').join(' | ')} |',
            ...table.rows.skip(1).map((r) => row(r.cells)),
          ].join('\n'),
        );
      } else {
        current.write('---');
      }
      continue;
    }
    final parts = (insert as String).split('\n');
    for (var i = 0; i < parts.length; i++) {
      current.write(_inline(parts[i], attributes));
      if (i < parts.length - 1) finish(attributes);
    }
  }
  if (current.isNotEmpty) finish({});
  final output = StringBuffer();
  if (entry.title.trim().isNotEmpty) {
    output.write('# ${_escape(entry.title.trim().replaceAll('\n', ' '))}\n\n');
  }
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) {
      final continuous =
          lines[i].kind == lines[i - 1].kind &&
          ['ordered', 'bullet', 'check', 'quote'].contains(lines[i].kind);
      output.write(continuous ? '\n' : '\n\n');
    }
    output.write(lines[i].text);
  }
  return output.toString().trimRight();
}
