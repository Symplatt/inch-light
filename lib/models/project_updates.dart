import 'journal_entry.dart';

class ProjectModule {
  ProjectModule({
    required this.id,
    required this.name,
    List<ProjectModule> children = const [],
  }) : children = List.unmodifiable(children);
  final String id;
  final String name;
  final List<ProjectModule> children;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'children': children.map((m) => m.toJson()).toList(),
  };
  factory ProjectModule.fromJson(Map<String, dynamic> json) => ProjectModule(
    id: json['id'] as String,
    name: json['name'] as String,
    children: (json['children'] as List? ?? [])
        .map((m) => ProjectModule.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

class ProjectUpdateItem {
  const ProjectUpdateItem({
    required this.moduleId,
    this.childId,
    required this.note,
  });
  final String moduleId;
  final String? childId;
  final JournalEntry note;
  Map<String, dynamic> toJson() => {
    'moduleId': moduleId,
    'childId': childId,
    'note': note.toJson(),
  };
  factory ProjectUpdateItem.fromJson(Map<String, dynamic> json) =>
      ProjectUpdateItem(
        moduleId: json['moduleId'] as String,
        childId: json['childId'] as String?,
        note: JournalEntry.fromJson(Map<String, dynamic>.from(json['note'])),
      );
}

class ProjectUpdate {
  const ProjectUpdate({
    required this.id,
    required this.version,
    required this.date,
    required String content,
    this.note,
    this.completed = false,
    this.items = const [],
  }) : _content = content;
  final String id;
  final String version;
  final DateTime date;
  final String _content;
  final JournalEntry? note;
  final bool completed;
  final List<ProjectUpdateItem> items;
  DateTime get editedAt => note?.updatedAt ?? date;

  ProjectUpdate withCompleted(bool value) => ProjectUpdate(
    id: id,
    version: version,
    date: date,
    content: content,
    note: note,
    completed: value,
    items: items,
  );
  String get content => note?.content ?? _content;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'date': date.toIso8601String(),
    'content': content,
    'completed': completed,
    'items': items.map((i) => i.toJson()).toList(),
    if (note != null) 'note': note!.toJson(),
  };

  factory ProjectUpdate.fromJson(Map<String, dynamic> json) {
    final update = ProjectUpdate(
      id: json['id'] as String,
      version: json['version'] as String,
      date: DateTime.parse(json['date'] as String),
      content: json['content'] as String,
      completed: json['completed'] as bool? ?? false,
      items: (json['items'] as List? ?? [])
          .map((i) => ProjectUpdateItem.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
      note: json['note'] == null
          ? null
          : JournalEntry.fromJson(Map<String, dynamic>.from(json['note'])),
    );
    if (update.id.isEmpty || update.version.trim().isEmpty) {
      throw const FormatException('Invalid project update');
    }
    return update;
  }
}

class UpdateProject {
  UpdateProject({
    required this.id,
    required this.name,
    this.updatedAt,
    List<ProjectUpdate> updates = const [],
    List<ProjectModule> modules = const [],
  }) : updates = List.unmodifiable(updates),
       modules = List.unmodifiable(modules);
  final String id;
  final String name;
  final DateTime? updatedAt;
  final List<ProjectUpdate> updates;
  final List<ProjectModule> modules;
  DateTime get editedAt => updates.fold(
    updatedAt ?? DateTime(1970),
    (latest, u) => u.editedAt.isAfter(latest) ? u.editedAt : latest,
  );

  UpdateProject withUpdates(List<ProjectUpdate> value) => UpdateProject(
    id: id,
    name: name,
    updates: value,
    modules: modules,
    updatedAt: DateTime.now(),
  );

  UpdateProject withModules(List<ProjectModule> value) => UpdateProject(
    id: id,
    name: name,
    updates: updates,
    modules: value,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'updates': updates.map((u) => u.toJson()).toList(),
    'modules': modules.map((m) => m.toJson()).toList(),
  };

  factory UpdateProject.fromJson(Map<String, dynamic> json) {
    final project = UpdateProject(
      id: json['id'] as String,
      name: json['name'] as String,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      modules: (json['modules'] as List? ?? [])
          .map((m) => ProjectModule.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      updates: (json['updates'] as List)
          .map((u) => ProjectUpdate.fromJson(Map<String, dynamic>.from(u)))
          .toList(),
    );
    if (project.id.isEmpty ||
        project.name.trim().isEmpty ||
        project.updates.map((u) => u.id).toSet().length !=
            project.updates.length) {
      throw const FormatException('Invalid update project');
    }
    return project;
  }
}

class ProjectUpdatesData {
  ProjectUpdatesData({required List<UpdateProject> projects, this.selectedId})
    : projects = List.unmodifiable(projects);
  final List<UpdateProject> projects;
  final String? selectedId;

  factory ProjectUpdatesData.empty() => ProjectUpdatesData(
    projects: [
      UpdateProject(id: 'inch_light', name: '一日千录'),
      UpdateProject(id: 'quota_starter', name: '额度启程'),
      UpdateProject(id: 'message_aggregation', name: '讯息聚合'),
    ],
    selectedId: 'inch_light',
  );

  UpdateProject? get selected {
    if (projects.isEmpty) return null;
    return projects.firstWhere(
      (p) => p.id == selectedId,
      orElse: () => projects.first,
    );
  }

  ProjectUpdatesData replace(UpdateProject project) => ProjectUpdatesData(
    projects: projects.map((p) => p.id == project.id ? project : p).toList(),
    selectedId: selectedId,
  );

  Map<String, dynamic> toJson() => {
    'projects': projects.map((p) => p.toJson()).toList(),
    'selectedId': selectedId,
  };

  factory ProjectUpdatesData.fromJson(Map<String, dynamic> json) {
    final projects = (json['projects'] as List)
        .map((p) => UpdateProject.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    if (projects.map((p) => p.id).toSet().length != projects.length ||
        projects.map((p) => p.name).toSet().length != projects.length) {
      throw const FormatException('Duplicate update project');
    }
    return ProjectUpdatesData(
      projects: projects,
      selectedId: json['selectedId'] as String?,
    );
  }
}
