import '../models/journal_entry.dart';
import '../models/journal_table.dart';

String _escape(String text) => text.replaceAllMapped(
  RegExp(r'[\\`*_{}\[\]<>#+\-.!|~=^]'),
  (match) => '\\${match[0]}',
);

String _inline(String text, Map attributes) {
  if (text.trim().isEmpty) return text;
  // Keep edge whitespace outside delimiters so emphasis remains valid Markdown.
  final leading = RegExp(r'^\s*').stringMatch(text)!;
  final trailing = RegExp(r'\s*$').stringMatch(text)!;
  if (attributes['code'] == true) {
    final raw = text.trim();
    final runs = RegExp(r'`+').allMatches(raw);
    final longest = runs.fold(
      0,
      (n, match) => match[0]!.length > n ? match[0]!.length : n,
    );
    final fence = '`' * (longest + 1);
    final pad = raw.startsWith('`') || raw.endsWith('`') ? ' ' : '';
    return '$leading$fence$pad$raw$pad$fence$trailing';
  }
  var value = _escape(text.trim());
  if (attributes['script'] == 'super') value = '^$value^';
  if (attributes['script'] == 'sub') value = '~$value~';
  if (attributes['italic'] == true) value = '*$value*';
  if (attributes['bold'] == true) value = '**$value**';
  if (attributes['strike'] == true) value = '~~$value~~';
  if (attributes['underline'] == true) value = '<u>$value</u>';
  if (attributes['background'] != null) value = '==$value==';
  return '$leading$value$trailing';
}

String journalTableToMarkdown(JournalTableData table) {
  String row(List<String> cells) =>
      '| ${cells.map((cell) => _escape(cell).replaceAll('\n', '<br>')).join(' | ')} |';
  return [
    row(table.rows.first.cells),
    '| ${List.filled(table.columns, ':---').join(' | ')} |',
    ...table.rows.skip(1).map((r) => row(r.cells)),
  ].join('\n');
}

/// Blank lines terminate a preceding list, quote or paragraph before the title.
String journalCollectionToMarkdown(Iterable<JournalEntry> entries) => entries
    .map(journalToMarkdown)
    .where((text) => text.isNotEmpty)
    .join('\n\n');

/// Exports the title and body, leaving dates, counts and organizational tags out
/// of the user's prose. Alignment uses HTML because Markdown has no equivalent.
String journalToMarkdown(JournalEntry entry) {
  final lines = <({String text, String kind})>[];
  var current = StringBuffer();
  String? previousChar;
  var previousCode = false;
  final punctuation = RegExp(r'^[\p{P}]$', unicode: true);
  var ordered = 0;
  void finish(Map attributes) {
    var text = current.toString();
    current = StringBuffer();
    previousChar = null;
    previousCode = false;
    var kind = 'paragraph';
    if (attributes['list'] != 'ordered') ordered = 0;
    final header = attributes['header'];
    if (header is int) {
      text = '${'#' * (header + 1).clamp(2, 6)} $text';
      kind = 'heading';
    } else {
      switch (attributes['list']) {
        case 'ordered':
          text = '${++ordered}. $text';
          kind = 'ordered';
        case 'bullet':
          text = '- $text';
          kind = 'bullet';
        case 'checked':
        case 'unchecked':
          text = '- [${attributes['list'] == 'checked' ? 'x' : ' '}] $text';
          kind = 'check';
      }
    }
    if (attributes['blockquote'] == true) {
      text = '> $text';
      kind = 'quote';
    }
    final align = attributes['align'];
    if (align == 'center' || align == 'right') {
      text = '<div align="$align">\n\n$text\n\n</div>';
      kind = 'html';
    }
    lines.add((text: text, kind: kind));
  }

  final operations = <Map<String, dynamic>>[];
  for (final raw in entry.document) {
    final op = Map<String, dynamic>.from(raw as Map);
    if (op['insert'] is String &&
        op['attributes']?['code'] == true &&
        operations.isNotEmpty &&
        operations.last['insert'] is String &&
        operations.last['attributes']?['code'] == true) {
      operations.last['insert'] = '${operations.last['insert']}${op['insert']}';
    } else {
      operations.add(op);
    }
  }
  for (final op in operations) {
    final attributes = op['attributes'] as Map? ?? {};
    final insert = op['insert'];
    if (insert is Map) {
      if (insert['table'] is String) {
        final table = JournalTableData.decode(insert['table']);
        current.write(journalTableToMarkdown(table));
      } else {
        current.write('---');
      }
      continue;
    }
    final parts = (insert as String).split('\n');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final code = attributes['code'] == true;
      if (part.isNotEmpty) {
        final left = previousChar;
        if (left != null &&
            left.trim().isNotEmpty &&
            part[0].trim().isNotEmpty &&
            ((code && !previousCode && !punctuation.hasMatch(left)) ||
                (previousCode && !code && !punctuation.hasMatch(part[0])))) {
          current.write(' ');
        }
        current.write(_inline(part, attributes));
        previousChar = part.substring(part.length - 1);
        previousCode = code;
      }
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
