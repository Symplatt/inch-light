import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import '../models/journal_entry.dart';
import '../models/project_updates.dart';
import '../providers/app_provider.dart';
import '../utils/project_update_note.dart';
import '../widgets/app_dialog.dart';
import '../widgets/swipe_delete_card.dart';
import '../widgets/tool_edit_dialog.dart';
import 'journal_editor_page.dart';

class ProjectUpdateEditorPage extends StatefulWidget {
  const ProjectUpdateEditorPage({
    super.key,
    required this.project,
    this.update,
  });

  final UpdateProject project;
  final ProjectUpdate? update;

  @override
  State<ProjectUpdateEditorPage> createState() =>
      _ProjectUpdateEditorPageState();
}

class _ProjectUpdateEditorPageState extends State<ProjectUpdateEditorPage> {
  late final _title = TextEditingController(text: widget.update?.version ?? '');
  final _titleFocus = FocusNode(canRequestFocus: false);
  late final _id = widget.update?.id ?? const Uuid().v4();
  late final _date = widget.update?.date ?? DateTime.now();
  Timer? _saveTimer;
  final _inlineKey = GlobalKey<JournalEditorState>();
  Future<bool> _flushInline() async =>
      await _inlineKey.currentState?.save() ?? true;

  bool _titleChanged = false;
  bool _allowTitleFocus = false;
  bool _leaving = false;

  UpdateProject get _project => context
      .read<AppProvider>()
      .projectUpdates
      .projects
      .firstWhere((project) => project.id == widget.project.id);

  void _stayBrowsing() {
    _inlineKey.currentState?.browse();
    if (_allowTitleFocus) setState(() => _allowTitleFocus = false);
    _titleFocus.canRequestFocus = false;
    _titleFocus.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    if (widget.update?.items.any(
          (item) => !projectUpdateItemHasContent(item),
        ) ??
        false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveWithFeedback();
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleFocus.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save({
    ProjectUpdateItem? item,
    String? deleteItemId,
    JournalEntry? legacyNote,
  }) async {
    final title = _title.text.trim().isEmpty ? '版本更新' : _title.text.trim();
    final now = DateTime.now();
    await context.read<AppProvider>().updateProjectUpdates((data) {
      final project = data.projects.firstWhere(
        (project) => project.id == widget.project.id,
      );
      final current = project.updates
          .where((update) => update.id == _id)
          .firstOrNull;
      final items = [...?current?.items];
      final legacy =
          legacyNote ??
          (current != null &&
                  current.items.isEmpty &&
                  (current.content.trim().isNotEmpty ||
                      (current.note?.document.any(
                            (op) => op['insert'] is Map,
                          ) ??
                          false))
              ? current.note ??
                    JournalEntry(
                      id: const Uuid().v4(),
                      title: '',
                      document: [
                        {'insert': '${current.content}\n'},
                      ],
                      createdAt: current.date,
                      updatedAt: current.editedAt,
                    )
              : null);
      // Keep a restored pre-grouping record when its first grouped item is added.
      if (item != null && legacy != null) {
        items.add(
          ProjectUpdateItem(
            moduleId: item.moduleId,
            childId: item.childId,
            note: JournalEntry(
              id: const Uuid().v4(),
              title: '',
              document: legacy.document,
              createdAt: legacy.createdAt,
              updatedAt: legacy.updatedAt,
            ),
          ),
        );
      }
      if (item != null) {
        final index = items.indexWhere(
          (saved) => saved.note.id == item.note.id,
        );
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
      }
      if (deleteItemId != null) {
        items.removeWhere((saved) => saved.note.id == deleteItemId);
      }
      items.removeWhere((saved) => !projectUpdateItemHasContent(saved));
      final draft = ProjectUpdate(
        id: _id,
        version: title,
        date: current?.date ?? _date,
        content: '',
        completed: current?.completed ?? false,
        items: items,
        note: JournalEntry(
          id: _id,
          title: title,
          document:
              legacy?.document ??
              const [
                {'insert': '\n'},
              ],
          createdAt: current?.date ?? _date,
          updatedAt: now,
        ),
      );
      final note = projectUpdateNote(project, draft);
      final saved = ProjectUpdate(
        id: draft.id,
        version: draft.version,
        date: draft.date,
        content: note.content,
        note: note,
        completed: draft.completed,
        items: items,
      );
      final updates = [...project.updates];
      final index = updates.indexWhere((update) => update.id == _id);
      if (index < 0) {
        updates.add(saved);
      } else {
        updates[index] = saved;
      }
      return data.replace(project.withUpdates(updates));
    });
  }

  Future<bool> _saveWithFeedback({String? deleteItemId}) async {
    try {
      await _save(deleteItemId: deleteItemId);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
      return false;
    }
  }

  Future<void> _deleteItem(String id) async {
    if (!await _saveWithFeedback(deleteItemId: id)) {
      throw StateError('保存失败');
    }
  }

  Future<void> _editLegacy(ProjectUpdate update) async {
    _stayBrowsing();
    final note =
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JournalEditorPage(
          projectMode: true,
          entry: note,
          saveEntry: (entry) => _save(legacyNote: entry),
        ),
      ),
    );
    if (mounted) _stayBrowsing();
  }

  void _changeTitle(String _) {
    _titleChanged = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveWithFeedback);
  }

  Future<void> _back() async {
    if (_leaving) return;
    _leaving = true;
    if (!await _flushInline()) {
      _leaving = false;
      return;
    }
    _saveTimer?.cancel();
    _stayBrowsing();
    if (_titleChanged && !await _saveWithFeedback()) {
      _leaving = false;
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editItem(
    ProjectModule module,
    ProjectModule? child, [
    ProjectUpdateItem? item,
  ]) async {
    _saveTimer?.cancel();
    _stayBrowsing();
    final now = DateTime.now();
    final note =
        item?.note ??
        JournalEntry(
          id: const Uuid().v4(),
          title: '',
          document: const [
            {'insert': '\n'},
          ],
          createdAt: now,
          updatedAt: now,
        );
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && await _flushInline() && dialogContext.mounted) {
            Navigator.pop(dialogContext);
          }
        },
        child: AppDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight:
                  (MediaQuery.sizeOf(dialogContext).height -
                          MediaQuery.viewInsetsOf(dialogContext).bottom -
                          80)
                      .clamp(160.0, 640.0),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: JournalEditorPage(
                editorKey: _inlineKey,
                entry: note,
                projectMode: true,
                inline: true,
                onClose: () => Navigator.pop(dialogContext),
                saveEntry: (entry) => _save(
                  item: ProjectUpdateItem(
                    moduleId: module.id,
                    childId: child?.id,
                    note: entry,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) _stayBrowsing();
  }

  Future<void> _editModule({
    ProjectModule? module,
    ProjectModule? parent,
  }) async {
    _stayBrowsing();
    final name = TextEditingController(text: module?.name ?? '');
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => ToolEditDialog(
        title:
            '${module == null ? '新增' : '编辑'}${parent == null ? '模块' : '子模块'}',
        fields: (enabled) => TextFormField(
          autofocus: true,
          controller: name,
          enabled: enabled,
          decoration: toolInputDecoration(parent == null ? '模块名称' : '子模块名称'),
          validator: requiredToolText,
        ),
        save: () => provider.updateProjectUpdates((data) {
          final project = data.projects.firstWhere(
            (project) => project.id == widget.project.id,
          );
          final currentParent = parent == null
              ? null
              : project.modules.firstWhere((saved) => saved.id == parent.id);
          final siblings = currentParent?.children ?? project.modules;
          final text = name.text.trim();
          if (siblings.any(
            (saved) => saved.id != module?.id && saved.name == text,
          )) {
            throw StateError('名称已存在');
          }
          final currentModule = siblings
              .where((saved) => saved.id == module?.id)
              .firstOrNull;
          final edited = ProjectModule(
            id: module?.id ?? const Uuid().v4(),
            name: text,
            children: currentModule?.children ?? [],
          );
          final changed = [
            for (final saved in siblings)
              saved.id == module?.id ? edited : saved,
            if (module == null) edited,
          ];
          final modules = currentParent == null
              ? changed
              : [
                  for (final saved in project.modules)
                    saved.id == currentParent.id
                        ? ProjectModule(
                            id: saved.id,
                            name: saved.name,
                            children: changed,
                          )
                        : saved,
                ];
          return data.replace(project.withModules(modules));
        }),
      ),
    );
    // The route's closing transition still owns its input field briefly.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _stayBrowsing();
    }
    name.dispose();
  }

  Future<void> _manageModules() async {
    if (!await _flushInline() || !mounted) return;
    _stayBrowsing();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer<AppProvider>(
        builder: (_, provider, _) {
          final project = _project;
          return AppAlertDialog(
            title: const Text('模块设置'),
            contentPadding: appSelectionContentPadding,
            content: SizedBox(
              width: 320,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.55,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final module in project.modules) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: 0,
                        minTileHeight: 48,
                        title: Text(
                          module.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () => _editModule(module: module),
                        onLongPress: () => _deleteModule(module),
                        trailing: IconButton(
                          tooltip: '新增子模块',
                          onPressed: () => _editModule(parent: module),
                          icon: const Icon(Icons.add, size: 20),
                        ),
                      ),
                      for (final child in module.children)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          tileColor: AppColors.bg,
                          dense: true,
                          minVerticalPadding: 0,
                          minTileHeight: 40,
                          title: Text(
                            child.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () =>
                              _editModule(module: child, parent: module),
                          onLongPress: () =>
                              _deleteModule(child, parent: module),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _editModule(),
                child: const Text('新增模块'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted) _stayBrowsing();
  }

  Future<void> _deleteModule(
    ProjectModule module, {
    ProjectModule? parent,
  }) async {
    bool belongs(ProjectUpdateItem item) => parent == null
        ? item.moduleId == module.id
        : item.moduleId == parent.id && item.childId == module.id;
    final count = _project.updates.expand((u) => u.items).where(belongs).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(parent == null ? '删除模块？' : '删除子模块？'),
        content: Text(
          parent == null
              ? '删除“${module.name}”、其中全部子模块及所有版本记录中的 $count 条事项。'
              : '删除“${module.name}”及所有版本记录中的 $count 条事项。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
    try {
      await context.read<AppProvider>().updateProjectUpdates((data) {
        final current = data.projects.firstWhere(
          (p) => p.id == widget.project.id,
        );
        final modules = parent == null
            ? current.modules.where((m) => m.id != module.id).toList()
            : [
                for (final m in current.modules)
                  m.id == parent.id
                      ? ProjectModule(
                          id: m.id,
                          name: m.name,
                          children: m.children
                              .where((c) => c.id != module.id)
                              .toList(),
                        )
                      : m,
              ];
        final project = current.withModules(modules);
        final updates = [
          for (final update in current.updates)
            if (update.items.isEmpty)
              update
            else
              _removeModuleItems(project, update, belongs, DateTime.now()),
        ];
        return data.replace(project.withUpdates(updates));
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }

  ProjectUpdate _removeModuleItems(
    UpdateProject project,
    ProjectUpdate update,
    bool Function(ProjectUpdateItem) belongs,
    DateTime now,
  ) {
    final items = update.items.where((item) => !belongs(item)).toList();
    // Empty groups must never restore the previous aggregate as legacy content.
    final draft = ProjectUpdate(
      id: update.id,
      version: update.version,
      date: update.date,
      content: '',
      completed: update.completed,
      items: items,
      note: JournalEntry(
        id: update.id,
        title: update.version,
        document: const [
          {'insert': '\n'},
        ],
        createdAt: update.date,
        updatedAt: now,
      ),
    );
    final note = projectUpdateNote(project, draft);
    return ProjectUpdate(
      id: draft.id,
      version: draft.version,
      date: draft.date,
      content: note.content,
      note: note,
      completed: draft.completed,
      items: items,
    );
  }

  Widget _group(
    ProjectModule module,
    ProjectModule? child,
    List<ProjectUpdateItem> items,
  ) {
    final entries = items
        .where(
          (i) =>
              i.moduleId == module.id &&
              i.childId == child?.id &&
              projectUpdateItemHasContent(i),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                child?.name ?? module.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            IconButton(
              tooltip: '新增事项',
              padding: EdgeInsets.zero,
              alignment: Alignment.centerRight,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: () => _editItem(module, child),
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: AppColors.divider),
          SwipeDeleteCard(
            key: ValueKey(entries[index].note.id),
            id: entries[index].note.id,
            bottomMargin: 0,
            onDeleted: () => _deleteItem(entries[index].note.id),
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => _editItem(module, child, entries[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (entries[index].note.title.trim().isNotEmpty) ...[
                        Text(
                          entries[index].note.title,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        entries[index].note.content.trim().isEmpty
                            ? '空白事项'
                            : entries[index].note.content,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final project = _project;
    final update = project.updates.where((u) => u.id == _id).firstOrNull;
    final items = update?.items ?? const <ProjectUpdateItem>[];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: BackButton(onPressed: _back),
          actions: [
            IconButton(
              tooltip: '模块设置',
              onPressed: _manageModules,
              icon: const Icon(Icons.tune),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Listener(
                        onPointerDown: (_) {
                          setState(() => _allowTitleFocus = true);
                          _titleFocus.canRequestFocus = true;
                        },
                        child: TextField(
                          controller: _title,
                          focusNode: _titleFocus,
                          canRequestFocus: _allowTitleFocus,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: '版本更新',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _changeTitle,
                          onTapOutside: (_) => _stayBrowsing(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        toolDateText(update?.editedAt ?? _date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (update != null &&
                    items.isEmpty &&
                    (update.content.trim().isNotEmpty ||
                        (update.note?.document.any(
                              (op) => op['insert'] is Map,
                            ) ??
                            false)))
                  Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => _editLegacy(update),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          update.content.trim().isEmpty
                              ? '查看原有内容'
                              : update.content,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                if (project.modules.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _editModule(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('新增模块'),
                    ),
                  ),
                for (final module in project.modules)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _group(module, null, items),
                        for (final child in module.children) ...[
                          const Divider(height: 16, color: AppColors.divider),
                          _group(module, child, items),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
