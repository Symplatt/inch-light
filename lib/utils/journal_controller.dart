import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import '../models/journal_table.dart';
import 'journal_table_markdown.dart';

/// Select a table on the first backspace and delete it on the next one. Keeping
/// this in the controller covers both IME replacements and hardware backspace.
class JournalController extends quill.QuillController {
  JournalController({
    required super.document,
    required super.selection,
    super.config,
  }) {
    onReplaceText = _replace;
    onDelete = (position, forward) {
      if (!forward && clearLeadingEmptyLines()) return;
      if (!forward && position > 0) {
        replaceText(
          position - 1,
          1,
          '',
          TextSelection.collapsed(offset: position - 1),
        );
      }
    };
  }
  int? pendingTable;
  bool _deleting = false;

  /// Insert on a clean paragraph without splitting or replacing existing prose.
  /// Compose once so whitespace cleanup and insertion share one undo step.
  void insertTable(JournalTableData table, TextSelection caret) {
    final plain = document.toPlainText();
    final offset = caret.start.clamp(0, plain.length - 1);
    final start = offset == 0 ? 0 : plain.lastIndexOf('\n', offset - 1) + 1;
    final end = plain.indexOf('\n', offset);
    final blank = plain.substring(start, end).trim().isEmpty;
    final last = end == plain.length - 1;
    final at = blank ? start : (last ? end : end + 1);
    final delta = Delta()..retain(at);
    // Quill requires the terminal newline to survive; insert before it.
    if (!blank && last) delta.insert('\n');
    if (blank) delta.delete(end - start + (last ? 0 : 1));
    delta
      ..insert({'table': table.encode()})
      ..insert('\n');
    if (blank && last) {
      final attributes = document.queryChild(end).node!.style.attributes;
      delta.retain(1, {for (final key in attributes.keys) key: null});
    }
    pendingTable = null;
    compose(
      delta,
      TextSelection.collapsed(offset: at + 2 + (!blank && last ? 1 : 0)),
      quill.ChangeSource.local,
    );
  }

  bool handleTableBackspace() {
    var offset = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map && insert['table'] is String) {
        if (pendingTable == offset && !selection.isCollapsed) {
          return deleteTable(JournalTableData.decode(insert['table']).id);
        }
        if (selection.isCollapsed &&
            selection.baseOffset >= offset &&
            selection.baseOffset <= offset + 2) {
          pendingTable = offset;
          updateSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
            quill.ChangeSource.local,
          );
          return true;
        }
      }
      offset += insert is String ? insert.length : 1;
    }
    return false;
  }

  /// Insert a plain paragraph before the existing embed, preserving its data
  /// and attributes and allowing the entire move to be undone in one step.
  bool moveTableDown(String id) {
    var offset = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map &&
          insert['table'] is String &&
          JournalTableData.decode(insert['table']).id == id) {
        pendingTable = null;
        compose(
          Delta()
            ..retain(offset)
            ..insert('\n'),
          TextSelection.collapsed(offset: offset),
          quill.ChangeSource.local,
        );
        return true;
      }
      offset += insert is String ? insert.length : 1;
    }
    return false;
  }

  bool deleteTable(String id) {
    var offset = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map &&
          insert['table'] is String &&
          JournalTableData.decode(insert['table']).id == id) {
        final length = document.length - offset > 2 ? 2 : 1;
        pendingTable = null;
        compose(
          Delta()
            ..retain(offset)
            ..delete(length),
          TextSelection.collapsed(offset: offset),
          quill.ChangeSource.local,
        );
        return true;
      }
      offset += insert is String ? insert.length : 1;
    }
    return false;
  }

  /// Only collapse leading blank paragraphs when the caret is inside them.
  /// Delete a document range so the first nonempty line retains its attributes.
  bool clearLeadingEmptyLines() {
    if (_deleting || !selection.isCollapsed) return false;
    final plain = document.toPlainText();
    final match = RegExp(r'^(?:[ \t]*\n)+').firstMatch(plain);
    if (match == null ||
        match.end >= plain.length ||
        selection.baseOffset < 0 ||
        selection.baseOffset >= match.end) {
      return false;
    }
    pendingTable = null;
    _deleting = true;
    try {
      // A raw deletion avoids Quill's ordinary paragraph-merge rule, which
      // would copy the empty first paragraph's style onto the surviving line.
      compose(
        Delta()..delete(match.end),
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    } finally {
      _deleting = false;
    }
    return true;
  }

  bool get onEmbedLine {
    if (!selection.isCollapsed) return true;
    final selected = selection.baseOffset;
    var at = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map && (selected == at || selected == at + 1)) return true;
      at += insert is String ? insert.length : 1;
    }
    return false;
  }

  bool _replace(int index, int length, Object? data) {
    if (data is String && data.contains('\n') && data.contains('|')) {
      final blocks = markdownTableBlocks(data);
      if (blocks.isNotEmpty) {
        final delta = Delta()
          ..retain(index)
          ..delete(length);
        var at = 0;
        var inserted = 0;
        void text(String value) {
          if (value.isNotEmpty) {
            delta.insert(value);
            inserted += value.length;
          }
        }

        final plain = document.toPlainText();
        for (final block in blocks) {
          text(data.substring(at, block.start));
          if (block.start == 0 && index > 0 && plain[index - 1] != '\n') {
            text('\n');
          }
          delta.insert({'table': block.table.encode()});
          inserted++;
          text('\n');
          at = block.end;
        }
        text(data.substring(at));
        pendingTable = null;
        compose(
          delta,
          TextSelection.collapsed(offset: index + inserted),
          quill.ChangeSource.local,
        );
        return false;
      }
    }
    if (_deleting) return true;
    if (data == '' &&
        length > 0 &&
        selection.isCollapsed &&
        index < selection.baseOffset &&
        clearLeadingEmptyLines()) {
      return false;
    }
    if (data != '' || length <= 0) {
      pendingTable = null;
      return true;
    }
    if (pendingTable != null &&
        selection.start == pendingTable &&
        !selection.isCollapsed) {
      handleTableBackspace();
      return false;
    }
    if (!selection.isCollapsed || length > 1) return true;
    var at = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map &&
          insert.containsKey('table') &&
          (index == at || index == at + 1) &&
          selection.baseOffset <= at + 2) {
        pendingTable = at;
        updateSelection(
          TextSelection(baseOffset: at, extentOffset: at + 1),
          quill.ChangeSource.local,
        );
        return false;
      }
      at += insert is String ? insert.length : 1;
    }
    pendingTable = null;
    return true;
  }

  @override
  void updateSelection(TextSelection textSelection, quill.ChangeSource source) {
    if (pendingTable != null &&
        (textSelection.start != pendingTable || textSelection.isCollapsed)) {
      pendingTable = null;
    }
    super.updateSelection(textSelection, source);
  }
}
