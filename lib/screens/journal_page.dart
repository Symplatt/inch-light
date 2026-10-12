import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/journal_entry.dart';
import '../providers/app_provider.dart';
import '../widgets/journal_tags.dart';
import '../widgets/position_border.dart';
import '../widgets/journal_export_icon.dart';
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
  final _search = TextEditingController();
  String? _selectedCollection;

  @override
  void initState() {
    super.initState();
    _selectedCollection = widget.collectionId;
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
    final input = TextEditingController(text: existing?.title ?? '');
    var deleteRequested = false;
    final title = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? '新建合集' : '修改合集名称'),
          content: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(hintText: '合集名称'),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  deleteRequested = true;
                  Navigator.pop(context, '');
                },
                child: const Text(
                  '删除合集',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (input.text.trim().isNotEmpty) {
                  Navigator.pop(context, input.text.trim());
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (title == null) return;
    if (deleteRequested && existing != null) {
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
      builder: (context) => AlertDialog(
        title: Text('删除“${folder.title}”？'),
        content: const Text('可以保留笔记并移入默认合集，也可以同时删除其中的笔记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留笔记，删除合集'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '删除合集和笔记',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
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

  Future<void> _delete(JournalEntry entry) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
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
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.removeJournalEntry(entry.id);
    } catch (_) {
      _error('删除未保存，请重试');
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
      await Clipboard.setData(
        ClipboardData(text: entries.map(journalToMarkdown).join()),
      );
      _error('合集 Markdown 已复制');
    } catch (_) {
      _error('复制失败，请重试');
    }
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
          setState(() => _selectedCollection = id);
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ValueKey('dismiss-note-${entry.id}'),
            direction: DismissDirection.horizontal,
            background: Container(
              color: AppColors.danger.withValues(alpha: .1),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
            secondaryBackground: Container(
              color: AppColors.danger.withValues(alpha: .1),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
            confirmDismiss: (_) async {
              await _delete(entry);
              return false;
            },
            child: _card(
              key: ValueKey('note-card-${entry.id}'),
              pinned: entry.isPinned,
              bottom: entry.isBottom,
              child: ListTile(
                visualDensity: const VisualDensity(vertical: -2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                onTap: () => _open(entry),
                onLongPress: () => _actions(entry),
              ),
            ),
          ),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('记录'),
        actions: [
          IconButton(
            tooltip: '发送合集',
            onPressed: _exportCollection,
            icon: const JournalExportIcon(multiple: true),
          ),
          IconButton(
            tooltip: '新建合集',
            onPressed: _collection,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-record-${widget.collectionId ?? 'root'}',
        tooltip: '新建记录',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _open,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              key: const ValueKey('record-search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
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
                          setState(() => _query = '');
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: notes,
                  ),
          ),
        ],
      ),
    );
  }
}
