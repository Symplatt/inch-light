import 'package:flutter/services.dart';

/// Layout-only padding must never become document text or an IME offset.
class InlineCodePadding {
  const InlineCodePadding(this.offset, {required this.leading});

  final int offset;
  final bool leading;
}

class InlineCodeOffsetMapping {
  const InlineCodeOffsetMapping([this.padding = const []]);

  final List<InlineCodePadding> padding;

  int toLayout(int offset, {bool? includePadding}) {
    var added = 0;
    for (final item in padding) {
      if (item.offset < offset ||
          (item.offset == offset && (includePadding ?? item.leading))) {
        added++;
      }
    }
    return offset + added;
  }

  int toDocument(int offset) {
    var added = 0;
    for (final item in padding) {
      if (item.offset + added >= offset) break;
      added++;
    }
    return offset - added;
  }

  TextPosition layoutPosition(TextPosition position) => TextPosition(
    offset: toLayout(
      position.offset,
      includePadding: position.affinity == TextAffinity.downstream,
    ),
    affinity: position.affinity,
  );

  TextPosition documentPosition(TextPosition position) => TextPosition(
    offset: toDocument(position.offset),
    affinity: position.affinity,
  );

  TextSelection layoutSelection(TextSelection selection) {
    if (selection.isCollapsed) {
      return TextSelection.fromPosition(layoutPosition(selection.extent));
    }
    final forward = selection.baseOffset < selection.extentOffset;
    return TextSelection(
      baseOffset: toLayout(selection.baseOffset, includePadding: forward),
      extentOffset: toLayout(selection.extentOffset, includePadding: !forward),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }
}
