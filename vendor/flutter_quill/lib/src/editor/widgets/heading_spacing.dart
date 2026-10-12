import '../../document/attribute.dart';
import '../../document/nodes/block.dart';
import '../../document/nodes/line.dart';
import 'default_styles.dart';
import '../../common/structs/vertical_spacing.dart';

/// Keep the first heading and consecutive headings tight. Extra top spacing is
/// only useful when a heading follows prose; it must not enter the document.
VerticalSpacing? contextualHeadingSpacing(Line line, DefaultStyles styles) {
  final level = line.style.attributes[Attribute.header.key]?.value;
  final style = switch (level) {
    1 => styles.h1,
    2 => styles.h2,
    3 => styles.h3,
    _ => null,
  };
  if (style == null) return null;
  var previous = line.previous ?? line.parent?.previous;
  if (previous is Block) previous = previous.children.last;
  final tight =
      previous == null ||
      previous.style.attributes.containsKey(Attribute.header.key);
  return VerticalSpacing(
    tight ? 0 : style.verticalSpacing.top,
    style.verticalSpacing.bottom,
  );
}
