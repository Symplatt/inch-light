import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/services.dart';

/// Applies a completed line-start shortcut from either a software or hardware
/// keyboard. It leaves pasted prose and markers in the middle of a line alone.
bool applyJournalShortcut(quill.QuillController controller) {
  final selection = controller.selection;
  if (!selection.isCollapsed || selection.baseOffset <= 0) return false;
  final plain = controller.document.toPlainText();
  final end = selection.baseOffset.clamp(0, plain.length);
  final start = plain.lastIndexOf('\n', end - 1) + 1;
  final prefix = plain.substring(start, end);
  quill.Attribute? attribute;
  final heading = RegExp(r'^(#{1,3}) $').firstMatch(prefix);
  if (heading != null) {
    attribute = [
      quill.Attribute.h1,
      quill.Attribute.h2,
      quill.Attribute.h3,
    ][heading[1]!.length - 1];
  } else if (RegExp(r'^[-*+] $').hasMatch(prefix)) {
    attribute = quill.Attribute.ul;
  } else if (RegExp(r'^\d+\. $').hasMatch(prefix)) {
    attribute = quill.Attribute.ol;
  } else if (prefix == '> ') {
    attribute = quill.Attribute.blockQuote;
  } else if (prefix == '- [ ] ' || prefix == '[ ] ') {
    attribute = quill.Attribute.unchecked;
  } else if (prefix == '- [x] ' || prefix == '[x] ') {
    attribute = quill.Attribute.checked;
  }
  if (attribute == null) return false;
  controller.replaceText(
    start,
    prefix.length,
    '',
    TextSelection.collapsed(offset: start),
  );
  controller.formatText(start, 0, attribute);
  return true;
}
