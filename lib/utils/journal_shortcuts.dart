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
  }
  if (attribute == null) return _inlineShortcut(controller, prefix, start);
  controller.replaceText(
    start,
    prefix.length,
    '',
    TextSelection.collapsed(offset: start),
  );
  controller.formatText(start, 0, attribute);
  return true;
}

bool _inlineShortcut(
  quill.QuillController controller,
  String prefix,
  int start,
) {
  // Longest markers first: **bold** must not be consumed as *italic*.
  final formats = <(String, List<quill.Attribute>)>[
    ('***', [quill.Attribute.bold, quill.Attribute.italic]),
    ('**', [quill.Attribute.bold]),
    ('__', [quill.Attribute.bold]),
    ('~~', [quill.Attribute.strikeThrough]),
    ('==', [const quill.BackgroundAttribute('#E6E6E6')]),
    ('*', [quill.Attribute.italic]),
    ('_', [quill.Attribute.italic]),
    ('`', [quill.Attribute.inlineCode]),
    ('^', [quill.Attribute.superscript]),
    ('~', [quill.Attribute.subscript]),
  ];
  for (final (marker, attributes) in formats) {
    if (!prefix.endsWith(marker)) continue;
    final closing = prefix.length - marker.length;
    if (closing <= marker.length) continue;
    final opening = prefix.lastIndexOf(marker, closing - 1);
    if (opening < 0 || closing <= opening + marker.length) continue;
    if (opening > 0 &&
        (prefix[opening - 1] == '\\' || prefix[opening - 1] == marker[0])) {
      continue;
    }
    final content = prefix.substring(opening + marker.length, closing);
    if (content.trim() != content || content.contains(marker[0])) continue;
    final at = start + opening;
    // Completed code spans stay literal when more Markdown markers are typed.
    final styles = controller.document.collectStyle(
      at,
      content.length + marker.length * 2,
    );
    if (styles.attributes['code']?.value == true) continue;
    controller.replaceText(
      start + closing,
      marker.length,
      '',
      TextSelection.collapsed(offset: start + closing),
    );
    controller.replaceText(
      at,
      marker.length,
      '',
      TextSelection.collapsed(offset: at + content.length),
    );
    for (final attribute in attributes) {
      controller.formatText(at, content.length, attribute);
    }
    // Do not continue the shortcut's style into the next characters.
    for (final attribute in attributes) {
      controller.formatSelection(quill.Attribute.clone(attribute, null));
    }
    return true;
  }
  return false;
}
