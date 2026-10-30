import '../models/journal_entry.dart';
import 'journal_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import '../models/journal_table.dart';
import 'journal_markdown_import.dart';

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
      if (!forward && handleListBackspace()) return;
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
  static String? _copiedMarkdown;
  static Delta? _copiedDocument;
  String? Function(String)? preparePaste;
  bool _preparingPaste = false;

  @override
  bool clipboardSelection(bool copy) {
    if (selection.isCollapsed || (!copy && readOnly)) return false;
    final range = selection;
    final delta = document.toDelta().slice(range.start, range.end);
    final last = delta.last.data;
    if (last is! String || !last.endsWith('\n')) {
      final line = document.queryChild(range.end - 1).node;
      delta.insert(
        '\n',
        line?.style.attributes.map((k, v) => MapEntry(k, v.value)),
      );
    }
    final formatted = delta.toList().any(
      (op) => op.data is! String || (op.attributes?.isNotEmpty ?? false),
    );
    final text = formatted
        ? journalToMarkdown(
            JournalEntry(
              id: '',
              title: '',
              document: delta.toJson(),
              createdAt: DateTime(1970),
              updatedAt: DateTime(1970),
            ),
          )
        : document.getPlainText(
            range.start,
            range.end - range.start,
            includeEmbeds: true,
          );
    copiedImageUrl = null;
    _copiedMarkdown = formatted ? text : null;
    _copiedDocument = formatted ? delta : null;
    Clipboard.setData(ClipboardData(text: text));
    if (!copy)
      replaceText(
        range.start,
        range.end - range.start,
        '',
        TextSelection.collapsed(offset: range.start),
      );
    return true;
  }

  /// Remove one continuous inline effect only when the caret lies inside it.
  bool clearInlineAtCaret(quill.Attribute attribute) {
    if (!selection.isCollapsed) return false;
    final position = selection.baseOffset;
    final active = <bool>[];
    for (final op in document.toDelta().toJson()) {
      final attrs = op['attributes'] as Map?;
      final match = attribute.key == 'background'
          ? (attrs?['background'] != null)
          : (attrs?[attribute.key] == attribute.value);
      final data = op['insert'];
      if (data is String) {
        for (var i = 0; i < data.length; i++)
          active.add(match && data[i] != '\n');
      } else {
        active.add(false);
      }
    }
    if (position <= 0 ||
        position >= active.length ||
        !active[position - 1] ||
        !active[position])
      return false;
    var start = position - 1;
    var end = position + 1;
    while (start > 0 && active[start - 1]) start--;
    while (end < active.length && active[end]) end++;
    formatText(start, end - start, quill.Attribute.clone(attribute, null));
    formatSelection(quill.Attribute.clone(attribute, null));
    return true;
  }

  int? pendingTable;
  bool _deleting = false;

  /// Unlist the first item at its start; remove only interior blank items.
  /// Raw deltas prevent Quill's paragraph merge from copying list attributes.
  bool handleListBackspace() {
    if (_deleting || !selection.isCollapsed || selection.baseOffset < 0) {
      return false;
    }
    final line = document.queryChild(selection.baseOffset).node;
    if (line is! quill.Line) {
      return false;
    }
    String? kind(quill.Node? node) {
      if (node is! quill.Line) return null;
      final value = node.toDelta().last.attributes?['list'];
      if (value == 'checked' || value == 'unchecked') return 'check';
      return value == 'ordered' || value == 'bullet' ? value as String : null;
    }

    final type = kind(line);
    if (type == null) return false;
    final start = line.documentOffset;
    final previous = start > 0 ? document.queryChild(start - 1).node : null;
    final blank = line.toPlainText().trim().isEmpty;
    if (!blank && (selection.baseOffset != start || kind(previous) == type)) {
      return false;
    }
    final nextAt = start + line.length;
    final next = nextAt < document.length
        ? document.queryChild(nextAt).node
        : null;
    final middle = kind(previous) == type && kind(next) == type;
    _deleting = true;
    pendingTable = null;
    try {
      final delta = Delta()..retain(start);
      if (blank && middle) {
        delta.delete(line.length);
      } else {
        if (blank) {
          delta.delete(line.length - 1);
        } else {
          delta.retain(line.length - 1);
        }
        delta.retain(1, {
          'list': null,
          'indent': null,
          if (line.toDelta().last.attributes?['blockquote'] == true)
            'blockquote': true,
        });
      }
      compose(
        delta,
        TextSelection.collapsed(offset: start),
        quill.ChangeSource.local,
      );
    } finally {
      _deleting = false;
    }
    return true;
  }

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
    if (!_deleting &&
        data is String &&
        data == _copiedMarkdown &&
        _copiedDocument != null) {
      final copied = _copiedDocument!;
      replaceText(
        index,
        length,
        copied,
        TextSelection.collapsed(offset: index),
      );
      return false;
    }
    if (!_preparingPaste && !_deleting && data is String && data.length > 1) {
      final next = preparePaste?.call(data);
      if (next != null) {
        _preparingPaste = true;
        try {
          replaceText(
            index,
            length,
            next,
            TextSelection.collapsed(offset: index + next.length),
          );
        } finally {
          _preparingPaste = false;
        }
        return false;
      }
    }
    if (!_deleting && data is String && data.length > 1) {
      final style = document.collectStyle(index, 0).attributes;
      if (style['code']?.value != true && style['code-block']?.value != true) {
        final parsed = journalMarkdownInsertion(data);
        if (parsed != null) {
          final plain = document.toPlainText();
          final insertion = Delta();
          if (parsed.blocks && index > 0 && plain[index - 1] != '\n') {
            insertion.insert('\n');
          }
          for (final op in parsed.delta.toList()) {
            insertion.push(op);
          }
          final end = index + length;
          var removed = length;
          // Reuse a blank target paragraph's newline instead of adding an
          // empty paragraph after every complete pasted block.
          if (parsed.blocks && end < plain.length && plain[end] == '\n') {
            removed++;
          }
          final change = Delta()
            ..retain(index)
            ..delete(removed);
          for (final op in insertion.toList()) {
            change.push(op);
          }
          pendingTable = null;
          final insertedLength = insertion.toList().fold<int>(
            0,
            (n, op) => n + (op.length ?? 0),
          );
          final caret = (index + insertedLength).clamp(
            0,
            document.length - removed + insertedLength - 1,
          );
          // Quill.compose transforms the old selection and ignores its supplied
          // selection; set the post-conversion caret before notifying listeners.
          document.compose(change, quill.ChangeSource.local);
          updateSelection(
            TextSelection.collapsed(offset: caret),
            quill.ChangeSource.local,
          );
          return false;
        }
      }
    }
    if (_deleting) return true;
    if (data == '' &&
        length > 0 &&
        selection.isCollapsed &&
        index < selection.baseOffset &&
        handleListBackspace()) {
      return false;
    }
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
  void formatText(
    int index,
    int len,
    quill.Attribute? attribute, {
    bool shouldNotifyListeners = true,
  }) {
    if (attribute == null || !['list', 'blockquote'].contains(attribute.key)) {
      super.formatText(
        index,
        len,
        attribute,
        shouldNotifyListeners: shouldNotifyListeners,
      );
      return;
    }
    final other = attribute.key == 'list' ? 'blockquote' : 'list';
    final lines = <({int at, Map<String, dynamic> attributes})>[];
    var start = 0;
    var offset = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is! String) {
        offset++;
        continue;
      }
      for (var i = 0; i < insert.length; i++) {
        if (insert[i] == '\n') {
          final at = offset + i;
          if (at >= index &&
              (start < index + len || len == 0 && start <= index)) {
            lines.add((
              at: at,
              attributes: Map<String, dynamic>.from(op['attributes'] ?? {}),
            ));
          }
          start = at + 1;
        }
      }
      offset += insert.length;
    }
    if (!lines.any((line) => line.attributes[other] != null)) {
      super.formatText(
        index,
        len,
        attribute,
        shouldNotifyListeners: shouldNotifyListeners,
      );
      return;
    }
    final delta = Delta();
    var at = 0;
    for (final line in lines) {
      delta
        ..retain(line.at - at)
        ..retain(1, {
          attribute.key: attribute.value,
          if (line.attributes[other] != null) other: line.attributes[other],
          if (attribute.value != null) 'header': null,
          if (attribute.value != null) 'code-block': null,
        });
      at = line.at + 1;
    }
    document.compose(delta, quill.ChangeSource.local);
    if (shouldNotifyListeners) notifyListeners();
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
