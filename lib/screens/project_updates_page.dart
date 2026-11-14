import '../utils/clipboard.dart';
import '../utils/journal_markdown.dart';
import '../models/journal_entry.dart';
import 'journal_editor_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
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

  Future<void> _clearUpdates(UpdateProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('清空更新记录？'),
        content: Text(
          '删除“${project.name}”下全部 ${project.updates.length} 条更新记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _update((data) {
      final current = data.projects
          .where((p) => p.id == project.id)
          .firstOrNull;
      return current == null ? data : data.replace(current.withUpdates([]));
    });
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
        contentPadding: appSelectionContentPadding,
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final project in projects)
                Dismissible(
                  key: ValueKey(project.id),
                  direction: DismissDirection.endToStart,
                  background: const SwipeDeleteBackground(),
                  confirmDismiss: (_) async {
                    Navigator.pop(ctx, (id: project.id, action: 'delete'));
                    return false;
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    minTileHeight: 40,
                    minVerticalPadding: 0,
                    title: Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onTap: () =>
                        Navigator.pop(ctx, (id: project.id, action: 'select')),
                    onLongPress: () =>
                        Navigator.pop(ctx, (id: project.id, action: 'edit')),
                    trailing: project.id == data.selected?.id
                        ? const Icon(Icons.check, size: 20)
                        : null,
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
              version: entry.title.trim().isEmpty ? '版本更新' : entry.title.trim(),
              completed: index < 0 ? false : updates[index].completed,
              date: index < 0 ? now : updates[index].date,
              content: entry.content,
              note: JournalEntry.fromJson({
                ...entry.toJson(),
                'title': entry.title.trim().isEmpty
                    ? '版本更新'
                    : entry.title.trim(),
              }),
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

  Future<void> _toggleCompleted(String projectId, String updateId) => _update((
    data,
  ) {
    final current = data.projects.firstWhere((p) => p.id == projectId);
    return data.replace(
      current.withUpdates(
        current.updates
            .map((u) => u.id == updateId ? u.withCompleted(!u.completed) : u)
            .toList(),
      ),
    );
  });

  Future<void> _copyUpdate(ProjectUpdate update) async {
    try {
      final note =
          update.note ??
          JournalEntry(
            id: update.id,
            title: update.version,
            document: [
              {'insert': '${update.content}\n'},
            ],
            createdAt: update.date,
            updatedAt: update.date,
          );
      // Project updates export their title and body without legacy note tags.
      await copyText(
        journalToMarkdown(
          JournalEntry.fromJson({...note.toJson(), 'tags': <String>[]}),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Markdown 已复制')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final project = provider.projectUpdates.selected;
    final updates = [...?project?.updates]
      ..sort((a, b) => b.editedAt.compareTo(a.editedAt));
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
              onPressed: project == null ? null : () => _openNote(project),
              icon: const Icon(Icons.add),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: '清空当前项目更新',
              onPressed: project == null || updates.isEmpty
                  ? null
                  : () => _clearUpdates(project),
              icon: const Icon(Icons.playlist_remove),
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
                        color: update.completed
                            ? const Color(0xFFF0F1F3)
                            : AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE7E8EB)),
                        ),
                        child: Semantics(
                          button: true,
                          checked: update.completed,
                          onTap: () => _openNote(project!, update),
                          onLongPress: () => _copyUpdate(update),
                          customSemanticsActions: {
                            CustomSemanticsAction(
                              label: update.completed ? '标为未完成' : '标为已完成',
                            ): () =>
                                _toggleCompleted(project!.id, update.id),
                          },
                          child: RawGestureDetector(
                            excludeFromSemantics: true,
                            gestures: {
                              LongPressGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    LongPressGestureRecognizer
                                  >(
                                    () => LongPressGestureRecognizer(
                                      duration: const Duration(seconds: 1),
                                    ),
                                    (recognizer) =>
                                        recognizer.onLongPress = () =>
                                            _copyUpdate(update),
                                  ),
                            },
                            child: InkWell(
                              excludeFromSemantics: true,
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openNote(project!, update),
                              onDoubleTap: () =>
                                  _toggleCompleted(project!.id, update.id),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            update.version,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              height: 1.25,
                                              decoration: update.completed
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          toolDateText(update.editedAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (update.content.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        update.content.replaceAll(
                                          RegExp(r'\s+'),
                                          '',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.45,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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
