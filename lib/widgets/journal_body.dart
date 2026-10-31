import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/journal_table.dart';
import '../constants/journal_colors.dart';
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

quill.DefaultStyles journalStyles({
  double fontSize = 18,
  double letterSpacing = 0,
  double lineHeight = 1.6,
  double paragraphSpacing = 10,
}) {
  quill.DefaultTextBlockStyle block(double size) =>
      journalBlock(size * fontSize / 18).copyWith(
        style: journalBlock(
          size * fontSize / 18,
        ).style.copyWith(letterSpacing: letterSpacing, height: lineHeight),
        verticalSpacing: quill.VerticalSpacing(0, paragraphSpacing),
      );
  quill.DefaultTextBlockStyle heading(double size, double top) =>
      block(size).copyWith(
        style: block(size).style.copyWith(fontWeight: FontWeight.w700),
        verticalSpacing: quill.VerticalSpacing(top, paragraphSpacing),
      );
  return quill.DefaultStyles(
    paragraph: block(18),
    quote: block(18).copyWith(
      lineSpacing: quill.VerticalSpacing(
        0,
        paragraphSpacing.clamp(4, double.infinity),
      ),
      style: block(18).style.copyWith(color: const Color(0xFF898989)),
      horizontalSpacing: const quill.HorizontalSpacing(0, 0),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD8D8D8), width: 1)),
      ),
    ),
    lists: quill.DefaultListBlockStyle(
      block(18).style,
      const quill.HorizontalSpacing(0, 0),
      quill.VerticalSpacing(0, paragraphSpacing),
      const quill.VerticalSpacing(0, 5),
      null,
      null,
      indentWidthBuilder: (block, _, _, _) => quill.HorizontalSpacing(
        block.style.attributes.containsKey('blockquote')
            ? (block.style.attributes.containsKey('list') ? 34 : 10)
            : 24,
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
  Color? gray(Color? color) {
    if (color == null) return null;
    final luminance = .2126 * color.r + .7152 * color.g + .0722 * color.b;
    return Color.from(
      alpha: color.a,
      red: luminance,
      green: luminance,
      blue: luminance,
    );
  }

  // Convert text colors here rather than filtering the whole page, so yellow
  // highlights also survive the image export's repaint boundary.
  style = style?.copyWith(
    color: gray(style.color),
    decorationColor: gray(style.decorationColor),
    backgroundColor: gray(style.backgroundColor),
  );
  // Display the previous built-in gray highlight in yellow without rewriting
  // saved documents; other imported colors keep their previous gray display.
  final background = node.style.attributes['background']?.value;
  if (background is String &&
      ['#E6E6E6', journalHighlightHex].contains(background.toUpperCase())) {
    style = (style ?? const TextStyle()).copyWith(
      backgroundColor: journalHighlightColor,
    );
  }
  final line = node is quill.Line ? node : node.parent;
  if (line?.style.attributes['header'] != null) {
    style = style?.copyWith(fontWeight: FontWeight.w700);
  } else if (node.style.attributes['bold']?.value == false) {
    style = style?.copyWith(fontWeight: FontWeight.w400);
  }
  if (line?.style.attributes['list']?.value == 'checked') {
    style = (style ?? const TextStyle()).copyWith(
      color: const Color(0xFF898989),
      decoration: TextDecoration.combine([
        if (style?.decoration != null) style!.decoration!,
        TextDecoration.lineThrough,
      ]),
    );
  }
  return TextSpan(text: text, recognizer: recognizer, style: style);
}

Widget? journalLeading(
  BuildContext context,
  quill.Node node,
  quill.LeadingConfig config, {
  bool readOnly = false,
  TextStyle? textStyle,
  Key? checkboxKey,
}) {
  final type = config.attribute.value;
  final check = ['checked', 'unchecked'].contains(type);
  if (!['ordered', 'bullet'].contains(type) && !check) {
    return null;
  }
  final baseStyle = textStyle ?? journalBlock(18).style;
  final style = node.style.attributes.containsKey('blockquote')
      ? baseStyle.copyWith(color: const Color(0xFF898989))
      : baseStyle;
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
  // Quote inset is additional to the marker gutter, never a narrower gutter.
  return Padding(
    padding: EdgeInsets.only(
      left: node.style.attributes.containsKey('blockquote') ? 10 : 0,
    ),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 24,
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: check
              ? SizedBox.square(
                  key: checkboxKey,
                  dimension: MediaQuery.textScalerOf(context).scale(18),
                  child: ExcludeFocus(
                    child: Checkbox(
                      value: config.value,
                      onChanged: readOnly || config.enabled == false
                          ? null
                          : (value) => config.onCheckboxTap(value!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      side: const BorderSide(
                        color: Color(0xFF707070),
                        width: 1.4,
                      ),
                      activeColor: const Color(0xFF606060),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                )
              : type == 'ordered'
              ? marker('${config.getIndexNumberByIndent}.')
              : marker('•'),
        ),
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
    this.onMoveDown,
    this.tableKeys,
    this.fontSize = 18,
    this.letterSpacing = .5,
    this.lineHeight = 1.5,
  });
  final ValueChanged<JournalTableData> onChanged;
  final String? autofocusId;
  final int? selectedOffset;
  final ValueChanged<String>? onDelete;
  final ValueChanged<String>? onMoveDown;
  final Map<String, GlobalKey>? tableKeys;
  final double fontSize;
  final double letterSpacing;
  final double lineHeight;
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
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          lineHeight: lineHeight,
          onChanged: onChanged,
          readOnly: embedContext.readOnly,
          autofocus: autofocusId == table.id,
          onDelete: onDelete == null ? null : () => onDelete!(table.id),
          onMoveDown: onMoveDown == null ? null : () => onMoveDown!(table.id),
        ),
      ),
    );
  }
}
