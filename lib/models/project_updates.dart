import 'journal_entry.dart';

class ProjectUpdate {
  const ProjectUpdate({
    required this.id,
    required this.version,
    required this.date,
    required String content,
    this.note,
  }) : _content = content;
  final String id;
  final String version;
  final DateTime date;
  final String _content;
  final JournalEntry? note;
  String get content => note?.content ?? _content;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'date': date.toIso8601String(),
    'content': content,
    if (note != null) 'note': note!.toJson(),
  };

  factory ProjectUpdate.fromJson(Map<String, dynamic> json) {
    final update = ProjectUpdate(
      id: json['id'] as String,
      version: json['version'] as String,
      date: DateTime.parse(json['date'] as String),
      content: json['content'] as String,
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
    List<ProjectUpdate> updates = const [],
  }) : updates = List.unmodifiable(updates);
  final String id;
  final String name;
  final List<ProjectUpdate> updates;

  UpdateProject withUpdates(List<ProjectUpdate> value) =>
      UpdateProject(id: id, name: name, updates: value);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'updates': updates.map((u) => u.toJson()).toList(),
  };

  factory UpdateProject.fromJson(Map<String, dynamic> json) {
    final project = UpdateProject(
      id: json['id'] as String,
      name: json['name'] as String,
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
