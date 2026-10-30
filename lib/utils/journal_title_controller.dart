import 'dart:ui' show FontFeature;
import 'package:flutter_quill/quill_delta.dart';
import '../models/journal_entry.dart';
import 'journal_markdown.dart';
import 'journal_operations.dart';
import 'package:flutter/material.dart';

/// Keep source offsets intact: selection and copying use the original Markdown.
/// Only complete pairs render; IME composition remains ordinary editable text.
class JournalTitleController extends TextEditingController {
  JournalTitleController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return journalTitleSpan(text, style);
  }
}

TextSpan journalTitleSpan(String source, TextStyle? style) {
  final pattern = RegExp(
    r'(`+)(.+?)\1|\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~|==(.+?)==|\*(.+?)\*|_(.+?)_|<u>(.+?)</u>|\^(.+?)\^|~(.+?)~',
  );
  final children = <InlineSpan>[];
  var at = 0;
  for (final match in pattern.allMatches(source)) {
    // Escaped delimiters are literal text.
    if (match.start > 0 && source[match.start - 1] == r'\') continue;
    if (match.start > at)
      children.add(TextSpan(text: source.substring(at, match.start)));
    final group = List.generate(
      10,
      (i) => i + 2,
    ).firstWhere((i) => match.group(i) != null);
    final content = match.group(group)!;
    final opening = group == 2
        ? match.group(1)!.length
        : group <= 6
        ? 2
        : group == 9
        ? 3
        : 1;
    final closing = group == 9 ? 4 : opening;
    const hidden = TextStyle(
      fontSize: 0,
      letterSpacing: 0,
      color: Colors.transparent,
    );
    children.add(
      TextSpan(text: match[0]!.substring(0, opening), style: hidden),
    );
    final base = style ?? const TextStyle();
    final rendered = switch (group) {
      2 => base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF0F0F0),
      ),
      3 || 4 => base.copyWith(fontWeight: FontWeight.w600),
      5 => base.copyWith(decoration: TextDecoration.lineThrough),
      6 => base.copyWith(backgroundColor: const Color(0xFFFFEFAD)),
      7 || 8 => base.copyWith(fontStyle: FontStyle.italic),
      9 => base.copyWith(decoration: TextDecoration.underline),
      10 => base.copyWith(fontFeatures: [const FontFeature.superscripts()]),
      _ => base.copyWith(fontFeatures: [const FontFeature.subscripts()]),
    };
    children.add(
      group == 2
          ? TextSpan(text: content, style: rendered)
          : journalTitleSpan(content, rendered),
    );
    children.add(
      TextSpan(
        text: match[0]!.substring(match[0]!.length - closing),
        style: hidden,
      ),
    );
    at = match.end;
  }
  if (at < source.length) children.add(TextSpan(text: source.substring(at)));
  return TextSpan(style: style, children: children);
}

/// Operations edit the formatted content, never interpret markup as punctuation.
String transformJournalTitle(String source, JournalOperation operation) {
  final delta = Delta();
  var formatted = false;
  void collect(TextSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (style.fontSize == 0) {
      formatted = true;
      return;
    }
    if (span.text != null && span.text!.isNotEmpty) {
      final attributes = <String, dynamic>{
        if (style.fontWeight == FontWeight.w600) 'bold': true,
        if (style.fontStyle == FontStyle.italic) 'italic': true,
        if (style.decoration?.contains(TextDecoration.lineThrough) == true)
          'strike': true,
        if (style.decoration?.contains(TextDecoration.underline) == true)
          'underline': true,
        if (style.fontFamily == 'monospace') 'code': true,
        if (style.backgroundColor == const Color(0xFFFFEFAD))
          'background': '#ffefad',
        if (style.fontFeatures?.contains(const FontFeature.superscripts()) ==
            true)
          'script': 'super',
        if (style.fontFeatures?.contains(const FontFeature.subscripts()) ==
            true)
          'script': 'sub',
      };
      delta.insert(span.text!, attributes.isEmpty ? null : attributes);
    }
    for (final child in span.children ?? <InlineSpan>[]) {
      if (child is TextSpan) collect(child, style);
    }
  }

  collect(journalTitleSpan(source, null), const TextStyle());
  if (!formatted) return transformJournalText(source, operation);
  delta.insert('\n');
  final document = transformJournalDocument(delta.toJson(), operation);
  return journalToMarkdown(
    JournalEntry(
      id: '',
      title: '',
      document: document,
      createdAt: DateTime(1970),
      updatedAt: DateTime(1970),
    ),
  );
}
