import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../widgets/directional_dismissible.dart';
import '../constants/app_colors.dart';
import '../models/journal_entry.dart';
import '../models/project_updates.dart';
import '../providers/app_provider.dart';
import '../utils/project_update_note.dart';
import '../utils/clipboard.dart';
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

  final _collapsedGroups = <String>{};
  static const _groupLeadingWidth = 28.0;

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
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: JournalEditorPage(
                editorKey: _inlineKey,
                entry: note,
                projectMode: true,
                inline: true,
                onClose: () => Navigator.pop(dialogContext),
                saveEntry: (entry) async {
                  final saved = ProjectUpdateItem(
                    moduleId: module.id,
                    childId: child?.id,
                    note: entry,
                  );
                  await _save(item: saved);
                  if (mounted &&
                      item == null &&
                      projectUpdateItemHasContent(saved)) {
                    setState(() {
                      _collapsedGroups.remove(module.id);
                      if (child != null) _collapsedGroups.remove(child.id);
                    });
                  }
                },
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
    var sorting = false;
    var savingOrder = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Consumer<AppProvider>(
          builder: (_, provider, _) {
            final modules = _project.modules;
            Future<void> reorder(
              List<ProjectModule> siblings,
              int from,
              int to, {
              String? parentId,
            }) async {
              if (from == to || savingOrder) return;
              setDialogState(() => savingOrder = true);
              final moved = siblings[from];
              final remaining = [...siblings]..removeAt(from);
              final beforeId = to < remaining.length ? remaining[to].id : null;
              try {
                await _reorderModules(provider, moved.id, beforeId, parentId);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(const SnackBar(content: Text('排序保存失败，请重试')));
                }
              } finally {
                if (context.mounted) setDialogState(() => savingOrder = false);
              }
            }

            Widget sortingCard(int index, {bool dragging = false}) {
              final module = modules[index];
              return _moduleSettingsCard(
                module,
                sortIndex: index,
                dragging: dragging,
                reorderChildren: (from, to) =>
                    reorder(module.children, from, to, parentId: module.id),
              );
            }

            return AppAlertDialog(
              constraints: appListDialogConstraints,
              titlePadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              title: Row(
                children: [
                  const Expanded(child: Text('模块设置')),
                  IconButton(
                    tooltip: sorting ? '结束排序' : '排序',
                    onPressed: savingOrder || modules.isEmpty
                        ? null
                        : () => setDialogState(() => sorting = !sorting),
                    icon: Icon(sorting ? Icons.check : Icons.sort, size: 20),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              content: SizedBox(
                width: 320,
                child: sorting
                    ? IgnorePointer(
                        ignoring: savingOrder,
                        child: ReorderableListView(
                          buildDefaultDragHandles: false,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          onReorderItem: (from, to) =>
                              reorder(modules, from, to),
                          proxyDecorator: (_, index, _) =>
                              sortingCard(index, dragging: true),
                          children: [
                            for (var index = 0; index < modules.length; index++)
                              sortingCard(index),
                          ],
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final module in modules)
                            _moduleSettingsCard(module),
                        ],
                      ),
              ),
              actions: [
                if (!sorting)
                  TextButton(
                    onPressed: () => _editModule(),
                    child: const Text('新增模块'),
                  ),
                TextButton(
                  onPressed: savingOrder
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (mounted) _stayBrowsing();
  }

  Future<void> _reorderModules(
    AppProvider provider,
    String movedId,
    String? beforeId,
    String? parentId,
  ) => provider.updateProjectUpdates((data) {
    final project = data.projects.firstWhere((p) => p.id == widget.project.id);
    final modules = [...project.modules];
    final parentIndex = modules.indexWhere((module) => module.id == parentId);
    if (parentId != null && parentIndex == -1) return data;
    final parent = parentIndex == -1 ? null : modules[parentIndex];
    final siblings = parent == null ? modules : [...parent.children];
    final from = siblings.indexWhere((module) => module.id == movedId);
    if (from == -1) return data;
    final moved = siblings.removeAt(from);
    final to = siblings.indexWhere((module) => module.id == beforeId);
    siblings.insert(to == -1 ? siblings.length : to, moved);
    if (parent != null) {
      modules[parentIndex] = ProjectModule(
        id: parent.id,
        name: parent.name,
        children: siblings,
      );
    }
    return data.replace(project.withModules(modules));
  });

  Widget _moduleSettingsCard(
    ProjectModule module, {
    int? sortIndex,
    bool dragging = false,
    ReorderCallback? reorderChildren,
  }) => Padding(
    key: ValueKey(module.id),
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: dragging ? BorderRadius.zero : BorderRadius.circular(12),
      elevation: dragging ? 6 : 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _moduleSettingsTile(module, sortIndex: sortIndex),
            if (sortIndex == null)
              for (final child in module.children)
                _moduleSettingsTile(child, parent: module),
            if (sortIndex != null && module.children.isNotEmpty)
              ReorderableListView(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                buildDefaultDragHandles: false,
                onReorderItem: reorderChildren,
                children: [
                  for (final (index, child) in module.children.indexed)
                    _moduleSettingsTile(
                      child,
                      parent: module,
                      sortIndex: index,
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  Widget _moduleSettingsTile(
    ProjectModule module, {
    ProjectModule? parent,
    int? sortIndex,
  }) {
    final isChild = parent != null;
    final name = Text(
      module.name,
      style: TextStyle(
        fontSize: isChild ? 14 : 16,
        fontWeight: FontWeight.w400,
      ),
    );
    final tile = ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      minTileHeight: isChild ? 40 : 48,
      title: isChild
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const ExcludeSemantics(
                  child: Text('•', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(child: name),
              ],
            )
          : name,
      onLongPress: sortIndex == null
          ? () => _editModule(module: module, parent: parent)
          : null,
      trailing: sortIndex != null
          ? SizedBox(
              width: 48,
              child: Icon(
                Icons.drag_handle,
                size: 20,
                semanticLabel: isChild ? '拖动子模块' : '拖动模块',
              ),
            )
          : isChild
          ? null
          : IconButton(
              tooltip: '新增子模块',
              onPressed: () => _editModule(parent: module),
              icon: const Icon(Icons.add, size: 20),
            ),
    );
    if (sortIndex == null) {
      return _moduleSettingRow(module, tile, parent: parent);
    }
    return ReorderableDelayedDragStartListener(
      key: ValueKey(module.id),
      index: sortIndex,
      child: tile,
    );
  }

  Widget _moduleSettingRow(
    ProjectModule module,
    Widget tile, {
    ProjectModule? parent,
  }) => DirectionalDismissible(
    key: ValueKey(module.id),
    direction: DismissDirection.endToStart,
    background: const SwipeDeleteBackground(),
    confirmDismiss: (_) async {
      await _deleteModule(module, parent: parent);
      return false;
    },
    child: Material(color: const Color(0xFFF7F7F7), child: tile),
  );

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

  void _toggleGroup(String id) {
    _stayBrowsing();
    setState(() {
      if (!_collapsedGroups.remove(id)) _collapsedGroups.add(id);
    });
  }

  void _toggleAllGroups() {
    _stayBrowsing();
    final ids = [
      for (final module in _project.modules) ...[
        module.id,
        for (final child in module.children) child.id,
      ],
    ];
    final allCollapsed = ids.every(_collapsedGroups.contains);
    setState(() {
      _collapsedGroups.clear();
      if (!allCollapsed) _collapsedGroups.addAll(ids);
    });
  }

  Future<void> _copyMarkdown() async {
    if (!await _flushInline() || !mounted) return;
    _saveTimer?.cancel();
    _stayBrowsing();
    if (_titleChanged && !await _saveWithFeedback()) return;
    if (!mounted) return;
    final project = _project;
    final update = project.updates.where((u) => u.id == _id).firstOrNull;
    if (update == null) return;
    try {
      await copyText(projectUpdateToMarkdown(project, update));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Markdown 已复制')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
      }
    }
  }

  Future<void> _clearGroup(ProjectModule module, ProjectModule? child) async {
    if (!await _flushInline() || !mounted) return;
    _saveTimer?.cancel();
    _stayBrowsing();
    try {
      await context.read<AppProvider>().updateProjectUpdates((data) {
        final project = data.projects.firstWhere(
          (p) => p.id == widget.project.id,
        );
        final updates = [
          for (final update in project.updates)
            if (update.id == _id)
              _removeModuleItems(
                project,
                update,
                (item) =>
                    item.moduleId == module.id &&
                    (child == null || item.childId == child.id),
                DateTime.now(),
              )
            else
              update,
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
    final numberMeasure = TextPainter(
      text: TextSpan(
        text: '${entries.length}.',
        style: const TextStyle(fontSize: 14),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final leadingWidth = (numberMeasure.width + 12).clamp(
      _groupLeadingWidth,
      double.infinity,
    );
    numberMeasure.dispose();
    final id = child?.id ?? module.id;
    final collapsed = _collapsedGroups.contains(id);
    final showEntries = !collapsed && entries.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DirectionalDismissible(
          key: ValueKey('group-header-$id'),
          direction: DismissDirection.endToStart,
          background: const SwipeDeleteBackground(),
          // The group remains available after its current update items are cleared.
          confirmDismiss: (_) async {
            await _clearGroup(module, child);
            return false;
          },
          child: Material(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _toggleGroup(id),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              child?.name ?? module.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(
                              0,
                              -1 / MediaQuery.devicePixelRatioOf(context),
                            ),
                            child: AnimatedRotation(
                              turns: collapsed ? 0 : 0.25,
                              duration: const Duration(milliseconds: 180),
                              child: const Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '新增事项',
                  padding: const EdgeInsets.only(right: 8),
                  alignment: Alignment.centerRight,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  onPressed: () => _editItem(module, child),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final child in previous)
                IgnorePointer(key: child.key, child: child),
              ?current,
            ],
          ),
          child: showEntries
              ? Padding(
                  key: const ValueKey('entries'),
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < entries.length; index++) ...[
                        if (index > 0)
                          const Divider(height: 1, color: Color(0xFFF1F2F4)),
                        SwipeDeleteCard(
                          key: ValueKey(entries[index].note.id),
                          id: entries[index].note.id,
                          bottomMargin: 0,
                          onDeleted: () => _deleteItem(entries[index].note.id),
                          child: Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () =>
                                  _editItem(module, child, entries[index]),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: leadingWidth,
                                      child: Text(
                                        '${index + 1}.',
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (entries[index].note.title
                                              .trim()
                                              .isNotEmpty) ...[
                                            Text(
                                              entries[index].note.title,
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          Text(
                                            entries[index].note.content,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final project = _project;
    final update = project.updates.where((u) => u.id == _id).firstOrNull;
    final items = update?.items ?? const <ProjectUpdateItem>[];
    final wordCount = items.isEmpty
        ? (update == null ? 0 : projectUpdateNote(project, update).wordCount)
        : items.fold<int>(0, (count, item) => count + item.note.wordCount);
    final groupIds = [
      for (final module in project.modules) ...[
        module.id,
        for (final child in module.children) child.id,
      ],
    ];
    final allCollapsed =
        groupIds.isNotEmpty && groupIds.every(_collapsedGroups.contains);
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
              tooltip: '复制 Markdown',
              onPressed: _copyMarkdown,
              icon: const Icon(Icons.content_copy_outlined, size: 22),
            ),
            IconButton(
              tooltip: allCollapsed ? '全部展开' : '全部收起',
              onPressed: project.modules.isEmpty ? null : _toggleAllGroups,
              icon: Icon(
                allCollapsed ? Icons.unfold_more : Icons.unfold_less,
                color: AppColors.textGrey,
              ),
            ),
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
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              fontSize: 28,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: '版本更新',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _changeTitle,
                            onTapOutside: (_) => _stayBrowsing(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Match the small metadata glyphs to the title's visible
                          // edges rather than their different font leading boxes.
                          Transform.translate(
                            offset: Offset(
                              0,
                              MediaQuery.textScalerOf(context).scale(0.7) - 1,
                            ),
                            child: Text(
                              toolDateText(update?.editedAt ?? _date),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Transform.translate(
                            offset: Offset(
                              0,
                              3 - MediaQuery.textScalerOf(context).scale(4),
                            ),
                            child: Text(
                              '$wordCount字',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                    key: ValueKey(module.id),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            items.any(
                              (item) =>
                                  item.moduleId == module.id &&
                                  projectUpdateItemHasContent(item),
                            )
                            ? const Color(0xFFDDDFE3)
                            : AppColors.divider,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _group(module, null, items),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: _collapsedGroups.contains(module.id)
                              ? const SizedBox.shrink()
                              : Column(
                                  children: [
                                    for (final child in module.children) ...[
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Divider(
                                          height: 16,
                                          color: AppColors.divider,
                                        ),
                                      ),
                                      _group(module, child, items),
                                    ],
                                  ],
                                ),
                        ),
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
