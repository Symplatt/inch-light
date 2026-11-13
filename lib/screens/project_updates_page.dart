import '../models/journal_entry.dart';
import 'journal_editor_page.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../models/project_updates.dart';
import '../providers/app_provider.dart';
import '../utils/journal_sort.dart';
import '../widgets/app_dialog.dart';
import '../widgets/swipe_delete_card.dart';
import '../widgets/tool_edit_dialog.dart';

class ProjectUpdatesPage extends StatefulWidget {
  const ProjectUpdatesPage({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<ProjectUpdatesPage> createState() => _ProjectUpdatesPageState();
}

class _ProjectUpdatesPageState extends State<ProjectUpdatesPage> {
  void _editProject([UpdateProject? project]) {
    showDialog<void>(
      context: context,
      builder: (_) => _ProjectNameDialog(
        project: project,
        provider: context.read<AppProvider>(),
      ),
    );
  }

  Future<void> _deleteProject(UpdateProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('删除项目？'),
        content: Text(
          '删除“${project.name}”及其中 ${project.updates.length} 条更新记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _update(
      (data) => ProjectUpdatesData(
        projects: data.projects.where((p) => p.id != project.id).toList(),
        selectedId: data.selectedId == project.id ? null : data.selectedId,
      ),
    );
  }

  Future<void> _update(
    ProjectUpdatesData Function(ProjectUpdatesData) change,
  ) async {
    try {
      await context.read<AppProvider>().updateProjectUpdates(change);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  Future<void> _projects() async {
    final provider = context.read<AppProvider>();
    final data = provider.projectUpdates;
    final projects = [
      ...data.projects,
    ]..sort((a, b) => JournalNameKey(a.name).compareTo(JournalNameKey(b.name)));
    final result = await showDialog<({String id, String action})>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('切换项目'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final project in projects)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(project.name),
                  onTap: () =>
                      Navigator.pop(ctx, (id: project.id, action: 'select')),
                  onLongPress: () =>
                      Navigator.pop(ctx, (id: project.id, action: 'edit')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (project.id == data.selected?.id)
                        const Icon(Icons.check, size: 20),
                      PopupMenuButton<String>(
                        tooltip: '项目操作',
                        onSelected: (action) => Navigator.pop(ctx, (
                          id: project.id,
                          action: action,
                        )),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑项目'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除项目'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final project = data.projects.firstWhere((p) => p.id == result.id);
    switch (result.action) {
      case 'edit':
        _editProject(project);
      case 'delete':
        await _deleteProject(project);
      default:
        await _update(
          (d) =>
              ProjectUpdatesData(projects: d.projects, selectedId: project.id),
        );
    }
  }

  void _editUpdate(UpdateProject project, [ProjectUpdate? update]) {
    if (update == null) {
      _openNote(project);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _ProjectUpdateDialog(
        provider: context.read<AppProvider>(),
        projectId: project.id,
        update: update,
      ),
    );
  }

  void _openNote(UpdateProject project, [ProjectUpdate? update]) {
    final provider = context.read<AppProvider>();
    final now = DateTime.now();
    final id = update?.id ?? const Uuid().v4();
    final note =
        update?.note ??
        JournalEntry(
          id: id,
          title: update?.version ?? '',
          document: [
            {'insert': '${update?.content ?? ''}\n'},
          ],
          createdAt: update?.date ?? now,
          updatedAt: now,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JournalEditorPage(
          entry: note,
          projectMode: true,
          saveEntry: (entry) => provider.updateProjectUpdates((data) {
            final current = data.projects.firstWhere((p) => p.id == project.id);
            final updates = [...current.updates];
            final index = updates.indexWhere((u) => u.id == id);
            final saved = ProjectUpdate(
              id: id,
              version: entry.title.trim().isEmpty ? '未命名更新' : entry.title,
              date: index < 0 ? now : updates[index].date,
              content: entry.content,
              note: entry,
            );
            if (index < 0) {
              updates.add(saved);
            } else {
              updates[index] = saved;
            }
            return data.replace(current.withUpdates(updates));
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final project = provider.projectUpdates.selected;
    final updates = [...?project?.updates]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: project == null
            ? const Text('歪脖扣腚')
            : OutlinedButton(
                onPressed: _projects,
                onLongPress: () => _editProject(project),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: Color(0xFFE7E8EB)),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
        actions: [
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: '新增项目',
              onPressed: _editProject,
              icon: const Icon(Icons.playlist_add),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: '新增更新',
              onPressed: project == null ? null : () => _editUpdate(project),
              icon: const Icon(Icons.add),
            ),
          ),
          SizedBox(
            width:
                8 +
                (MediaQuery.sizeOf(context).width - 720).clamp(
                      0.0,
                      double.infinity,
                    ) /
                    2,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: updates.isEmpty
              ? Center(
                  child: Text(
                    project == null ? '请先新增项目' : '暂无更新记录',
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: updates.length,
                  itemBuilder: (context, index) {
                    final update = updates[index];
                    return SwipeDeleteCard(
                      key: ValueKey(update.id),
                      id: update.id,
                      bottomMargin: 8,
                      onDeleted: () => provider.updateProjectUpdates((data) {
                        final current = data.projects.firstWhere(
                          (p) => p.id == project!.id,
                        );
                        return data.replace(
                          current.withUpdates(
                            current.updates
                                .where((u) => u.id != update.id)
                                .toList(),
                          ),
                        );
                      }),
                      child: Material(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE7E8EB)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openNote(project!, update),
                          onLongPress: () => _editUpdate(project!, update),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      update.version,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      toolDateText(update.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                if (update.content.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    update.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ProjectNameDialog extends StatefulWidget {
  const _ProjectNameDialog({required this.provider, this.project});
  final AppProvider provider;
  final UpdateProject? project;
  @override
  State<_ProjectNameDialog> createState() => _ProjectNameDialogState();
}

class _ProjectNameDialogState extends State<_ProjectNameDialog> {
  late final _name = TextEditingController(text: widget.project?.name);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolEditDialog(
    title: widget.project == null ? '新增项目' : '编辑项目',
    fields: (enabled) => TextFormField(
      controller: _name,
      enabled: enabled,
      autofocus: true,
      decoration: const InputDecoration(labelText: '项目名称'),
      validator: requiredToolText,
    ),
    save: () => widget.provider.updateProjectUpdates((data) {
      final name = _name.text.trim();
      if (data.projects.any(
        (p) => p.id != widget.project?.id && p.name == name,
      )) {
        throw StateError('项目名称已存在');
      }
      if (widget.project == null) {
        final project = UpdateProject(id: const Uuid().v4(), name: name);
        return ProjectUpdatesData(
          projects: [...data.projects, project],
          selectedId: project.id,
        );
      }
      final current = data.projects.firstWhere(
        (p) => p.id == widget.project!.id,
      );
      return data.replace(
        UpdateProject(id: current.id, name: name, updates: current.updates),
      );
    }),
  );
}

class _ProjectUpdateDialog extends StatefulWidget {
  const _ProjectUpdateDialog({
    required this.provider,
    required this.projectId,
    this.update,
  });
  final AppProvider provider;
  final String projectId;
  final ProjectUpdate? update;
  @override
  State<_ProjectUpdateDialog> createState() => _ProjectUpdateDialogState();
}

class _ProjectUpdateDialogState extends State<_ProjectUpdateDialog> {
  late final _version = TextEditingController(text: widget.update?.version);

  late DateTime _date = widget.update?.date ?? DateTime.now();
  @override
  void dispose() {
    _version.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolEditDialog(
    title: widget.update == null ? '新增更新' : '编辑更新',
    fields: (enabled) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _version,
          enabled: enabled,
          autofocus: true,
          decoration: const InputDecoration(labelText: '版本号'),
          validator: requiredToolText,
        ),
        const SizedBox(height: 16),
        ToolDateField(
          label: '更新日期',
          initialDate: _date,
          enabled: enabled,
          onChanged: (date) => _date = date,
        ),
      ],
    ),
    save: () => widget.provider.updateProjectUpdates((data) {
      final project = data.projects.firstWhere((p) => p.id == widget.projectId);
      final update = ProjectUpdate(
        id: widget.update?.id ?? const Uuid().v4(),
        version: _version.text.trim(),
        date: _date,
        content: widget.update?.content ?? '',
        note: widget.update?.note == null
            ? null
            : JournalEntry.fromJson({
                ...widget.update!.note!.toJson(),
                'title': _version.text.trim(),
              }),
      );
      final updates = [...project.updates];
      final index = updates.indexWhere((u) => u.id == update.id);
      if (index < 0) {
        updates.add(update);
      } else {
        updates[index] = update;
      }
      return data.replace(project.withUpdates(updates));
    }),
  );
}
