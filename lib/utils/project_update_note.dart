import '../models/journal_entry.dart';
import '../models/project_updates.dart';
import 'journal_markdown.dart';

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
  if (update.items.isEmpty) return journalToMarkdown(_legacyNote(update));
  final sections = <String>['# ${update.version.trim().replaceAll('\n', ' ')}'];
  for (final group in _updateGroups(project, update)) {
    sections.add(
      '${group.child == null ? '##' : '###'} ${group.child?.name ?? group.module.name}',
    );
    final entries = <String>[];
    for (final (index, item) in group.items.indexed) {
      // A historical title remains prose inside its item instead of becoming
      // another heading alongside the configured module hierarchy.
      final body = journalToMarkdown(
        JournalEntry(
          id: item.note.id,
          title: '',
          document: [
            if (item.note.title.trim().isNotEmpty)
              {'insert': '${item.note.title}\n'},
            ...item.note.document,
          ],
          createdAt: item.note.createdAt,
          updatedAt: item.note.updatedAt,
        ),
      );
      final marker = '${index + 1}. ';
      final lines = body.split('\n');
      final indent = ' ' * marker.length;
      entries.add(
        '$marker${lines.first}${lines.skip(1).map((line) => '\n$indent$line').join()}',
      );
    }
    if (entries.isNotEmpty) sections.add(entries.join('\n\n'));
  }
  return sections.join('\n\n');
}
