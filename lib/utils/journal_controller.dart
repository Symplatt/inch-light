import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
    if (_deleting) return true;
    if (data != '' || length <= 0) {
      pendingTable = null;
      return true;
    }
    if (pendingTable != null &&
        selection.start == pendingTable &&
        !selection.isCollapsed) {
      final at = pendingTable!;
      pendingTable = null;
      _deleting = true;
      // Remove the embed and its paragraph ending, preserving the paragraph
      // below it and therefore never merging surrounding prose accidentally.
      replaceText(at, 2, '', TextSelection.collapsed(offset: at));
      _deleting = false;
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
