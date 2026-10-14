import '../utils/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/journal_entry.dart';
import '../providers/app_provider.dart';
import '../widgets/journal_tags.dart';
import '../widgets/journal_collection_dialog.dart';
import '../widgets/position_border.dart';
import '../widgets/journal_export_icon.dart';
import '../widgets/swipe_delete_card.dart';
import '../utils/journal_markdown.dart';
import 'journal_editor_page.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, this.collectionId});
  final String? collectionId;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  String _query = '';
  bool _selecting = false;
  bool _batchBusy = false;
  final _selected = <String>{};
  Offset? _swipeStart;

  void _exitSelection() => setState(() {
    _selecting = false;
    _selected.clear();
    _swipeStart = null;
  });

  Future<void> _batchAction({required bool delete}) async {
    if (_selected.isEmpty || _batchBusy) return;
    final provider = context.read<AppProvider>();
    final ids = Set<String>.from(_selected);
    String? target;
    if (delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('删除选中的 ${ids.length} 篇笔记？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                '删除',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      target = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('移动到合集'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('默认'),
            ),
            for (final folder in provider.journalCollections)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, folder.id),
                child: Text(folder.title),
              ),
          ],
        ),
      );
      if (target == null) return;
    }
    if (!mounted) return;
    setState(() => _batchBusy = true);
    try {
      if (delete) {
        await provider.removeJournalEntries(ids);
      } else {
        await provider.moveJournalEntries(ids, target!.isEmpty ? null : target);
      }
      if (mounted) _exitSelection();
    } catch (_) {
      _error(delete ? '删除未保存，请重试' : '移动未保存，请重试');
    } finally {
      if (mounted) setState(() => _batchBusy = false);
    }
  }

  Widget _selectableNote(JournalEntry entry, Widget card) => Listener(
    onPointerDown: (event) => _swipeStart = event.position,
    onPointerUp: (_) => _swipeStart = null,
    onPointerCancel: (_) => _swipeStart = null,
    onPointerMove: (event) {
      if (_selecting || _swipeStart == null) return;
      final delta = event.position - _swipeStart!;
      if (delta.dx > 24 && delta.dx > delta.dy.abs()) {
        setState(() => _selecting = true);
      }
    },
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _selecting ? 44 : 0,
          height: _selecting ? 48 : 0,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 44,
              maxWidth: 44,
              child: IconButton(
                tooltip: _selected.contains(entry.id) ? '取消选择' : '选择笔记',
                onPressed: !_selecting || _batchBusy
                    ? null
                    : () => setState(() {
                        if (!_selected.add(entry.id)) {
                          _selected.remove(entry.id);
                        }
                      }),
                icon: Icon(
                  _selected.contains(entry.id)
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SwipeDeleteCard(
            key: ValueKey('dismiss-note-${entry.id}'),
            id: entry.id,
            enabled: !_selecting,
            bottomMargin: 0,
            onDeleted: () => _delete(entry, swipe: true),
            child: card,
          ),
        ),
      ],
    ),
  );

  final _search = TextEditingController();
  String? _selectedCollection;

  @override
  void initState() {
    super.initState();
    _selectedCollection =
        widget.collectionId ??
        context.read<AppProvider>().lastJournalCollection;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open([JournalEntry? entry]) {
    FocusScope.of(context).unfocus();
    final provider = context.read<AppProvider>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: JournalEditorPage(
            entry: entry,
            collectionId: _selectedCollection,
          ),
        ),
      ),
    );
  }

  Future<void> _collection([JournalCollection? existing]) async {
    final provider = context.read<AppProvider>();
    final title = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .22),
      builder: (_) => JournalCollectionDialog(title: existing?.title),
    );
    if (!mounted || title == null) return;
    if (title.isEmpty && existing != null) {
      await _deleteCollection(existing);
      return;
    }
    try {
      if (existing == null) {
        await provider.addJournalCollection(title);
      } else {
        await provider.renameJournalCollection(existing.id, title);
      }
    } catch (_) {
      _error('合集保存失败，请重试');
    }
  }

  Future<void> _deleteCollection(JournalCollection folder) async {
    final provider = context.read<AppProvider>();
    final deleteNotes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .22),
      builder: (_) => JournalDeleteCollectionDialog(
        title: folder.title,
        count: provider.journalEntries
            .where((e) => e.collectionId == folder.id)
            .length,
      ),
    );
    if (deleteNotes == null) return;
    try {
      await provider.removeJournalCollection(
        folder.id,
        deleteEntries: deleteNotes,
      );
      if (mounted && _selectedCollection == folder.id) {
        setState(() => _selectedCollection = null);
      }
    } catch (_) {
      _error('删除失败，请重试');
    }
  }

  void _error(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  Future<void> _delete(JournalEntry entry, {bool swipe = false}) async {
    final provider = context.read<AppProvider>();
    final confirmed =
        swipe ||
        (await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('删除记录？'),
                content: Text(entry.title.isEmpty ? '未命名' : entry.title),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '删除',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ) ??
            false);
    if (confirmed != true) return;
    try {
      await provider.removeJournalEntry(entry.id, recoverable: swipe);
    } catch (_) {
      _error('删除未保存，请重试');
      if (swipe) rethrow;
    }
  }

  Future<void> _restore() async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复最近删除的笔记？'),
        content: Text(
          '恢复过去一分钟内滑动删除的 ${provider.recoverableJournalCount} 篇笔记，已超过一分钟的笔记不会恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final count = await provider.restoreRecentJournalEntries();
      _error(count == 0 ? '可恢复的笔记已超过一分钟' : '已恢复 $count 篇笔记');
    } catch (_) {
      _error('恢复失败，请重试');
    }
  }

  Future<void> _actions(JournalEntry entry) async {
    final provider = context.read<AppProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: Text(entry.isPinned ? '取消置顶' : '置顶'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_bottom),
              title: Text(entry.isBottom ? '取消置底' : '置底'),
              onTap: () => Navigator.pop(context, 'bottom'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移动到合集'),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'delete') {
      await _delete(entry);
      return;
    }
    try {
      if (action == 'pin') {
        await provider.saveJournalEntry(
          entry.copyWith(isPinned: !entry.isPinned),
        );
      } else if (action == 'bottom') {
        await provider.saveJournalEntry(
          entry.copyWith(isBottom: !entry.isBottom),
        );
      } else {
        final target = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('移动到合集'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('默认'),
              ),
              for (final folder in provider.journalCollections)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, folder.id),
                  child: Text(folder.title),
                ),
            ],
          ),
        );
        if (target != null) {
          await provider.saveJournalEntry(
            entry.copyWith(
              collectionId: target.isEmpty ? null : target,
              move: true,
            ),
          );
        }
      }
    } catch (_) {
      _error('记录保存失败，请重试');
    }
  }

  bool _inCollection(JournalEntry entry, List<JournalCollection> collections) =>
      _selectedCollection != null
      ? entry.collectionId == _selectedCollection
      : entry.collectionId == null ||
            !collections.any((c) => c.id == entry.collectionId);

  Future<void> _exportCollection() async {
    final provider = context.read<AppProvider>();
    final entries = provider.journalEntries.where(
      (e) => _inCollection(e, provider.journalCollections),
    );
    try {
      await copyText(journalCollectionToMarkdown(entries));
      _error('合集 Markdown 已复制');
    } catch (_) {
      _error('复制失败，请重试');
    }
  }

  void _selectCollection(String? id) {
    FocusScope.of(context).unfocus();
    context.read<AppProvider>().setLastJournalCollection(id);
    setState(() {
      _selectedCollection = id;
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _showCollections() async {
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          final folders = provider.journalCollections;
          Widget tile(String? id, String name) => ListTile(
            title: Text(name),
            trailing: Text(
              '${provider.journalEntries.where((e) => id == null ? e.collectionId == null : e.collectionId == id).length}',
            ),
            selected: _selectedCollection == id,
            onTap: () {
              Navigator.pop(dialogContext);
              _selectCollection(id);
            },
          );
          return AlertDialog(
            title: Text('合集 · ${folders.length + 1}'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  tile(null, '默认'),
                  for (final folder in folders)
                    SwipeDeleteCard(
                      key: ValueKey('collection-list-${folder.id}'),
                      id: folder.id,
                      bottomMargin: 0,
                      onDeleted: () async {
                        try {
                          await provider.removeJournalCollection(
                            folder.id,
                            deleteEntries: false,
                          );
                        } catch (_) {
                          _error('合集删除失败，请重试');
                          rethrow;
                        }
                      },
                      child: Material(
                        color: AppColors.surface,
                        child: tile(folder.id, folder.title),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _collectionTab(
    String? id,
    String title, {
    JournalCollection? folder,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      key: ValueKey('note-folder-${id ?? 'default'}'),
      color: _selectedCollection == id ? const Color(0xFFE8EAED) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onLongPress: folder == null ? null : () => _collection(folder),
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _selectedCollection = id;
            context.read<AppProvider>().setLastJournalCollection(id);
            _selecting = false;
            _selected.clear();
            _swipeStart = null;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3D3D3D),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _card({
    required Widget child,
    Key? key,
    bool pinned = false,
    bool bottom = false,
  }) => Material(
    key: key,
    color: AppColors.surface,
    shape: PositionBorder(pinned: pinned, bottom: bottom),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_selectedCollection != null &&
        !provider.journalCollections.any((c) => c.id == _selectedCollection)) {
      _selectedCollection = null;
    }
    final collections = provider.journalCollections;
    final query = _query.trim().toLowerCase();
    final entries = provider.journalEntries.where((entry) {
      final inScope =
          (_selectedCollection == null && query.isNotEmpty) ||
          _inCollection(entry, collections);
      return inScope &&
          (query.isEmpty ||
              entry.title.toLowerCase().contains(query) ||
              entry.tags.any((tag) => tag.toLowerCase().contains(query)));
    }).toList();
    final notes = <Widget>[
      for (final entry in entries)
        Padding(
          key: ValueKey(entry.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: _selectableNote(
            entry,
            _card(
              key: ValueKey('note-card-${entry.id}'),
              pinned: entry.isPinned,
              bottom: entry.isBottom,
              child: ListTile(
                visualDensity: const VisualDensity(vertical: -2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                trailing: SizedBox(
                  width: 24,
                  child: entry.isPinned || entry.isBottom
                      ? Icon(
                          entry.isPinned
                              ? Icons.vertical_align_top
                              : Icons.vertical_align_bottom,
                          size: 18,
                          color: AppColors.textGrey,
                        )
                      : null,
                ),
                titleAlignment: ListTileTitleAlignment.center,
                title: Text(
                  entry.title.isEmpty ? '未命名' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
                subtitle: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              constraints.maxWidth *
                              (entry.tags.isEmpty ? 1 : .65),
                        ),
                        child: Text(
                          '${DateFormat('M月d日 HH:mm').format(entry.updatedAt)}  |  ${entry.wordCount}字',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      if (entry.tags.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: JournalTags(tags: entry.tags, compact: true),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                onTap: () {
                  if (_selecting) {
                    if (!_batchBusy) {
                      setState(() {
                        if (!_selected.add(entry.id)) {
                          _selected.remove(entry.id);
                        }
                      });
                    }
                  } else {
                    _open(entry);
                  }
                },
                onLongPress: _selecting ? null : () => _actions(entry),
              ),
            ),
          ),
        ),
    ];
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _exitSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  tooltip: '退出多选',
                  onPressed: _batchBusy ? null : _exitSelection,
                  icon: const Icon(Icons.close),
                )
              : null,
          title: Text(_selecting ? '已选 ${_selected.length} 项' : '记录'),
          actions: [
            if (_selecting)
              IconButton(
                tooltip: '全选',
                onPressed: _batchBusy
                    ? null
                    : () => setState(() {
                        final all = entries.map((e) => e.id).toSet();
                        if (all.isNotEmpty && _selected.containsAll(all)) {
                          _selected.clear();
                        } else {
                          _selected.addAll(all);
                        }
                      }),
                icon: const Icon(Icons.library_add_check_outlined),
              )
            else ...[
              if (provider.recoverableJournalCount > 0)
                IconButton(
                  tooltip: '恢复',
                  onPressed: _restore,
                  icon: const JournalActionIcon(JournalActionSymbol.restore),
                ),
              IconButton(
                tooltip: '新建合集',
                onPressed: _collection,
                icon: const JournalActionIcon(JournalActionSymbol.folder),
              ),
              IconButton(
                tooltip: '批量导出 Markdown',
                onPressed: _exportCollection,
                icon: const JournalExportIcon(multiple: true),
              ),
            ],
          ],
        ),
        floatingActionButton: _selecting
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'move-records',
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    onPressed: _selected.isEmpty || _batchBusy
                        ? null
                        : () => _batchAction(delete: false),
                    label: const Text('批量移动'),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'delete-records',
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    onPressed: _selected.isEmpty || _batchBusy
                        ? null
                        : () => _batchAction(delete: true),
                    label: const Text('全部删除'),
                  ),
                ],
              )
            : FloatingActionButton(
                heroTag: 'add-record-${widget.collectionId ?? 'root'}',
                tooltip: '新建记录',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: _open,
                child: const Icon(Icons.add),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                key: const ValueKey('record-search'),
                controller: _search,
                onChanged: (value) => setState(() {
                  _query = value;
                  _selected.clear();
                }),
                decoration: InputDecoration(
                  hintText: '搜索标题和标签',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {
                              _query = '';
                              _selected.clear();
                            });
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                key: const ValueKey('collection-tabs'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _collectionTab(null, '默认'),
                    for (final folder in collections)
                      _collectionTab(folder.id, folder.title, folder: folder),
                    IconButton(
                      tooltip: '查看合集列表',
                      onPressed: _showCollections,
                      icon: const Icon(Icons.view_list_outlined),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty ? '暂无记录' : '没有匹配的记录',
                        style: const TextStyle(color: AppColors.textGrey),
                      ),
                    )
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        _selecting ? 160 : 96,
                      ),
                      children: notes,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
