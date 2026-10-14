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
  quill.DefaultTextBlockStyle heading(double size, double top) =>
      journalBlock(size).copyWith(
        style: journalBlock(size).style.copyWith(fontWeight: FontWeight.w600),
        verticalSpacing: quill.VerticalSpacing(top, 8),
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
        block.style.attributes.containsKey('blockquote') ? 10 : 24,
        0,
      ),
      numberPointWidthBuilder: (_, _) => 24,
    ),
    h1: heading(26, 48),
    h2: heading(23, 32),
    h3: heading(20, 16),
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
  if (!['ordered', 'bullet'].contains(type)) {
    return null;
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
      width: 24,
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
    this.onDelete,
    this.tableKeys,
  });
  final ValueChanged<JournalTableData> onChanged;
  final String? autofocusId;
  final int? selectedOffset;
  final ValueChanged<String>? onDelete;
  final Map<String, GlobalKey>? tableKeys;
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
          key:
              tableKeys?.putIfAbsent(table.id, GlobalKey.new) ??
              ValueKey(table.id),
          data: table,
          onChanged: onChanged,
          readOnly: embedContext.readOnly,
          autofocus: autofocusId == table.id,
          onDelete: onDelete == null ? null : () => onDelete!(table.id),
        ),
      ),
    );
  }
}
