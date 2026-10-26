import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/journal_table.dart';
import 'journal_table_markdown.dart';

typedef MarkdownInsertion = ({Delta delta, bool blocks});

/// Parse only the incoming text. Existing rich text and code are never reparsed.
MarkdownInsertion? journalMarkdownInsertion(String source) {
  // Keep the existing table cell decoder (escaped pipes and literal markup)
  // so copied tables retain their exact cell values and receive fresh IDs.
  final tables = markdownTableBlocks(source);
  if (tables.isNotEmpty) {
    final delta = Delta();
    void text(String part) {
      if (part.isEmpty) return;
      final parsed = journalMarkdownInsertion(part);
      if (parsed == null) {
        delta.insert(part);
      } else {
        for (final op in parsed.delta.toList()) {
          delta.push(op);
        }
      }
    }

    void newline() {
      if (delta.isNotEmpty &&
          (delta.last.data is! String ||
              !(delta.last.data as String).endsWith('\n'))) {
        delta.insert('\n');
      }
    }

    var at = 0;
    for (final table in tables) {
      text(source.substring(at, table.start));
      newline();
      delta
        ..insert({'table': table.table.encode()})
        ..insert('\n');
      at = table.end;
    }
    text(source.substring(at));
    newline();
    return (delta: delta, blocks: true);
  }
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(source.replaceAll('\r\n', '\n').split('\n'));
  var recognized = false;
  var blocks = false;
  void inspect(md.Node node) {
    if (node is! md.Element) return;
    if (['strong', 'em', 'del', 'code', 'a', 'br'].contains(node.tag)) {
      recognized = true;
    }
    if ([
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'ul',
      'ol',
      'blockquote',
      'pre',
      'table',
      'hr',
    ].contains(node.tag)) {
      recognized = true;
      blocks = true;
    }
    node.children?.forEach(inspect);
  }

  nodes.forEach(inspect);
  if (!recognized) return null;
  final writer = _MarkdownWriter();
  writer.writeBlocks(nodes, const {});
  var delta = writer.delta;
  // A single inline fragment must stay on the current paragraph.
  if (!blocks && !source.endsWith('\n') && nodes.length == 1) {
    delta = delta.slice(0, delta.length - 1);
  }
  return (delta: delta, blocks: blocks);
}

class _MarkdownWriter {
  final delta = Delta();

  void inline(md.Node node, Map<String, dynamic> attributes) {
    if (node is md.Text) {
      delta.insert(node.text, attributes.isEmpty ? null : attributes);
      return;
    }
    if (node is! md.Element || node.tag == 'input') return;
    if (node.tag == 'br') {
      delta.insert('\n');
      return;
    }
    final next = <String, dynamic>{...attributes};
    switch (node.tag) {
      case 'strong':
        next['bold'] = true;
      case 'em':
        next['italic'] = true;
      case 'del':
        next['strike'] = true;
      case 'code':
        next['code'] = true;
      case 'a':
        next['link'] = node.attributes['href'];
      case 'img':
        // Preserve the label and address without fetching external media.
        delta.insert(
          '${node.attributes['alt'] ?? ''} (${node.attributes['src'] ?? ''})',
        );
        return;
    }
    for (final child in node.children ?? <md.Node>[]) {
      inline(child, next);
    }
  }

  void paragraph(List<md.Node> nodes, Map<String, dynamic> attributes) {
    for (final node in nodes) {
      inline(node, const {});
    }
    delta.insert('\n', attributes.isEmpty ? null : attributes);
  }

  void writeBlocks(
    List<md.Node> nodes,
    Map<String, dynamic> attributes, [
    int depth = 0,
  ]) {
    for (final node in nodes) {
      if (node is! md.Element) {
        paragraph([node], attributes);
        continue;
      }
      final children = node.children ?? <md.Node>[];
      switch (node.tag) {
        case 'ul':
        case 'ol':
          for (final item in children.whereType<md.Element>()) {
            String? checked;
            void findCheck(md.Node child) {
              if (child is! md.Element) return;
              if (child.tag == 'input') {
                checked = child.attributes.containsKey('checked')
                    ? 'checked'
                    : 'unchecked';
              } else if (child.tag != 'ul' && child.tag != 'ol') {
                child.children?.forEach(findCheck);
              }
            }

            item.children?.forEach(findCheck);
            final style = <String, dynamic>{
              ...attributes,
              'list': checked ?? (node.tag == 'ol' ? 'ordered' : 'bullet'),
              if (depth > 0) 'indent': depth.clamp(1, 8),
            };
            final run = <md.Node>[];
            void flush() {
              if (run.isEmpty) return;
              paragraph(run, style);
              run.clear();
            }

            for (final child in item.children ?? <md.Node>[]) {
              if (child is md.Element && ['ul', 'ol'].contains(child.tag)) {
                flush();
                writeBlocks([child], const {}, depth + 1);
              } else if (child is md.Element && child.tag == 'p') {
                flush();
                paragraph(child.children ?? [], style);
              } else {
                run.add(child);
              }
            }
            flush();
          }
        case 'blockquote':
          writeBlocks(children, {'blockquote': true}, depth);
        case 'pre':
          final code = node.textContent.replaceFirst(RegExp(r'\n$'), '');
          for (final line in code.split('\n')) {
            if (line.isNotEmpty) delta.insert(line);
            delta.insert('\n', {'code-block': true});
          }
        case 'hr':
          delta
            ..insert({'divider': 'hr'})
            ..insert('\n');
        case 'table':
          final rows = <List<String>>[];
          void row(md.Node child) {
            if (child is! md.Element) return;
            if (child.tag == 'tr') {
              rows.add(
                (child.children ?? []).map((cell) => cell.textContent).toList(),
              );
            } else {
              child.children?.forEach(row);
            }
          }
          children.forEach(row);
          if (rows.isNotEmpty && rows.first.length <= 12) {
            final table = JournalTableData.empty(
              rows.length,
              rows.first.length,
            );
            final data = JournalTableData(
              id: table.id,
              columns: table.columns,
              rows: List.generate(
                rows.length,
                (i) => JournalTableRow(id: table.rows[i].id, cells: rows[i]),
              ),
            );
            delta
              ..insert({'table': data.encode()})
              ..insert('\n');
          } else {
            paragraph([md.Text(node.textContent)], attributes);
          }
        default:
          final heading = RegExp(r'^h([1-6])$').firstMatch(node.tag);
          paragraph(children, {
            ...attributes,
            if (heading != null) 'header': int.parse(heading[1]!),
          });
      }
    }
  }
}
