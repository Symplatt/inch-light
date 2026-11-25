import '../models/journal_entry.dart';
import '../models/project_updates.dart';
import 'journal_markdown.dart';
import 'journal_operations.dart';

const projectUpdateCleanupOperations = [
  JournalOperation.removeLeadingPunctuation,
  JournalOperation.clearBlankLines,
];

typedef _UpdateGroup = ({
  ProjectModule module,
  ProjectModule? child,
  List<ProjectUpdateItem> items,
});

bool projectUpdateItemHasContent(ProjectUpdateItem item) =>
    item.note.title.trim().isNotEmpty ||
    item.note.content.trim().isNotEmpty ||
    item.note.document.any((operation) => operation['insert'] is Map);

Iterable<_UpdateGroup> _updateGroups(
  UpdateProject project,
  ProjectUpdate update,
) sync* {
  final items = update.items.where(projectUpdateItemHasContent);
  for (final module in project.modules) {
    final direct = items
        .where((item) => item.moduleId == module.id && item.childId == null)
        .toList();
    final children = <_UpdateGroup>[
      for (final child in module.children)
        (
          module: module,
          child: child,
          items: items
              .where(
                (item) =>
                    item.moduleId == module.id && item.childId == child.id,
              )
              .toList(),
        ),
    ].where((group) => group.items.isNotEmpty).toList();
    if (direct.isEmpty && children.isEmpty) continue;
    yield (module: module, child: null, items: direct);
    yield* children;
  }
}

JournalEntry _legacyNote(ProjectUpdate update) =>
    update.note ??
    JournalEntry(
      id: update.id,
      title: update.version,
      document: [
        {'insert': '${update.content}\n'},
      ],
      createdAt: update.date,
      updatedAt: update.editedAt,
    );

/// Build exports from the project configuration so renamed groups stay current.
JournalEntry projectUpdateNote(UpdateProject project, ProjectUpdate update) {
  if (update.items.isEmpty) return _legacyNote(update);
  final document = <dynamic>[];
  for (final group in _updateGroups(project, update)) {
    document.add({'insert': group.child?.name ?? group.module.name});
    document.add({
      'insert': '\n',
      'attributes': {'header': group.child == null ? 1 : 2},
    });
    for (final item in group.items) {
      if (item.note.title.trim().isNotEmpty) {
        document.add({'insert': item.note.title});
        document.add({
          'insert': '\n',
          'attributes': {'header': 3},
        });
      }
      document.addAll(item.note.document);
      document.add({'insert': '\n'});
    }
  }
  if (document.isEmpty) document.add({'insert': '\n'});
  return JournalEntry(
    id: update.id,
    title: update.version,
    document: document,
    createdAt: update.date,
    updatedAt: update.editedAt,
  );
}

String projectUpdateToMarkdown(UpdateProject project, ProjectUpdate update) {
  return _projectUpdateMarkdown(
    project,
    update,
  ).split('\n').where((line) => line.trim().isNotEmpty).join('\n');
}

String _projectUpdateMarkdown(UpdateProject project, ProjectUpdate update) {
  if (update.items.isEmpty) return _exportMarkdown(_legacyNote(update));
  final sections = <String>['# ${update.version.trim().replaceAll('\n', ' ')}'];
  for (final group in _updateGroups(project, update)) {
    sections.add(
      '${group.child == null ? '##' : '###'} ${group.child?.name ?? group.module.name}',
    );
    final entries = <String>[];
    for (final (index, item) in group.items.indexed) {
      // A historical title remains prose inside its item instead of becoming
      // another heading alongside the configured module hierarchy.
      final body = _exportMarkdown(item.note, grouped: true);
      entries.add(_numberUpdateBody(body, index + 1));
    }
    if (entries.isNotEmpty) sections.add(entries.join('\n\n'));
  }
  return sections.join('\n\n');
}

String _exportMarkdown(JournalEntry note, {bool grouped = false}) {
  var document = <dynamic>[
    if (grouped && note.title.trim().isNotEmpty) {'insert': '${note.title}\n'},
    ...note.document,
  ];
  for (final operation in projectUpdateCleanupOperations) {
    document = transformJournalDocument(document, operation);
  }
  return journalToMarkdown(
    JournalEntry(
      id: note.id,
      title: grouped ? '' : note.title,
      titleBold: note.titleBold,
      document: document,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    ),
  );
}

// Plain-text numbering keeps item hierarchy independent of Markdown lists.
String _numberUpdateBody(String body, int number) {
  final listMarker = RegExp(r'^\s*(?:\d+\. |[-*] (?:\[[ x]\] )?)(.*)$');
  final lines = body.trim().split('\n');
  final hasList = lines.any((line) => listMarker.hasMatch(line));
  final paragraphs = <String>[];
  final prose = <String>[];
  void flushProse() {
    if (prose.isNotEmpty) {
      paragraphs.add(prose.join(' '));
      prose.clear();
    }
  }

  var childNumber = 0;
  for (final line in lines) {
    final match = listMarker.firstMatch(line);
    if (match != null) {
      flushProse();
      paragraphs.add('$number.${++childNumber} ${match[1]}');
    } else if (line.trim().isNotEmpty) {
      // Tables, headings and quotes retain their block boundaries and syntax.
      if (RegExp(r'^(?:\||#{1,6} |>|---$|<div|</div>)').hasMatch(line)) {
        flushProse();
        if (line.startsWith('|') &&
            paragraphs.isNotEmpty &&
            paragraphs.last.startsWith('|')) {
          paragraphs[paragraphs.length - 1] += '\n$line';
        } else {
          paragraphs.add(line);
        }
      } else {
        prose.add(line.trim());
      }
    }
  }
  flushProse();
  final text = paragraphs.join('\n\n');
  return hasList && listMarker.hasMatch(lines.first)
      ? '$number\n$text'
      : '$number $text';
}
