import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/journal_table.dart';
import 'journal_table.dart';

quill.DefaultTextBlockStyle journalBlock(double size) =>
    quill.DefaultTextBlockStyle(
      TextStyle(
        fontSize: size,
        color: const Color(0xFF3D3D3D),
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(0, 8),
      const quill.VerticalSpacing(0, 0),
      null,
    );

quill.DefaultStyles journalStyles() {
  quill.DefaultTextBlockStyle heading(double size) =>
      journalBlock(size).copyWith(
        style: journalBlock(size).style.copyWith(fontWeight: FontWeight.w600),
        verticalSpacing: const quill.VerticalSpacing(12, 8),
      );
  return quill.DefaultStyles(
    paragraph: journalBlock(18),
    quote: journalBlock(18).copyWith(
      style: journalBlock(18).style.copyWith(color: const Color(0xFF898989)),
      horizontalSpacing: const quill.HorizontalSpacing(0, 0),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD8D8D8), width: 1)),
      ),
    ),
    lists: quill.DefaultListBlockStyle(
      journalBlock(18).style,
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(0, 8),
      const quill.VerticalSpacing(0, 5),
      null,
      null,
      indentWidthBuilder: (block, _, _, _) => quill.HorizontalSpacing(
        block.style.attributes.containsKey('blockquote') ? 10 : 28,
        0,
      ),
      numberPointWidthBuilder: (_, _) => 28,
    ),
    h1: heading(26),
    h2: heading(23),
    h3: heading(20),
  );
}

InlineSpan journalSpan(
  BuildContext context,
  quill.Node node,
  int offset,
  String text,
  TextStyle? style,
  GestureRecognizer? recognizer,
) {
  final line = node is quill.Line ? node : node.parent;
  if (line?.style.attributes['header'] != null) {
    style = style?.copyWith(fontWeight: FontWeight.w600);
  }
  return TextSpan(text: text, recognizer: recognizer, style: style);
}

Widget? journalLeading(
  BuildContext context,
  quill.Node node,
  quill.LeadingConfig config, {
  bool readOnly = false,
}) {
  final type = config.attribute.value;
  if (!['ordered', 'bullet', 'checked', 'unchecked'].contains(type)) {
    return null;
  }
  if (type == 'checked' || type == 'unchecked') {
    // The editor constrains this marker to the actual first line's height.
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: readOnly ? null : () => config.onCheckboxTap(!config.value),
        child: Icon(
          config.value
              ? Icons.check_box_outlined
              : Icons.check_box_outline_blank,
          size: MediaQuery.textScalerOf(context).scale(18),
          color: const Color(0xFF3D3D3D),
        ),
      ),
    );
  }
  final style = journalBlock(18).style;
  final strut = StrutStyle.fromTextStyle(style);
  final painter = TextPainter(
    text: TextSpan(
      text: node.toPlainText().trimRight().isEmpty
          ? ' '
          : node.toPlainText().trimRight(),
      style: style,
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    strutStyle: strut,
  )..layout();
  final height = painter.height;
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  painter.dispose();
  Widget marker(String text) => Baseline(
    baseline: baseline,
    baselineType: TextBaseline.alphabetic,
    child: RichText(
      text: TextSpan(text: text, style: style),
      strutStyle: strut,
      textScaler: MediaQuery.textScalerOf(context),
    ),
  );
  // Constrain to the first line, not the full height of a wrapped list item.
  return Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 28,
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: type == 'ordered'
            ? marker('${config.getIndexNumberByIndent}.')
            : marker('•'),
      ),
    ),
  );
}

class JournalDividerBuilder extends quill.EmbedBuilder {
  const JournalDividerBuilder();
  @override
  String get key => 'divider';
  @override
  String toPlainText(quill.Embed node) => '';
  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) =>
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(color: Color(0xFFCCCCCC), height: 1),
      );
}

class JournalTableBuilder extends quill.EmbedBuilder {
  const JournalTableBuilder({
    required this.onChanged,
    this.autofocusId,
    this.selectedOffset,
  });
  final ValueChanged<JournalTableData> onChanged;
  final String? autofocusId;
  final int? selectedOffset;
  @override
  String get key => 'table';
  @override
  String toPlainText(quill.Embed node) =>
      JournalTableData.decode(node.value.data as String).plainText;
  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final table = JournalTableData.decode(
      embedContext.node.value.data as String,
    );
    final selected = selectedOffset == embedContext.node.documentOffset;
    return Opacity(
      opacity: selected ? .4 : 1,
      child: IgnorePointer(
        ignoring: selected,
        child: JournalTable(
          key: ValueKey(table.id),
          data: table,
          onChanged: onChanged,
          readOnly: embedContext.readOnly,
          autofocus: autofocusId == table.id,
        ),
      ),
    );
  }
}
