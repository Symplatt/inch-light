import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/journal_entry.dart';
import '../providers/app_provider.dart';
import '../widgets/journal_tags.dart';
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
            collectionId: widget.collectionId,
          ),
        ),
      ),
    );
  }

  Future<void> _collection([JournalCollection? existing]) async {
    final provider = context.read<AppProvider>();
    final input = TextEditingController(text: existing?.title ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? '新建合集' : '修改合集名称'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(hintText: '合集名称'),
        ),
        actions: [
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
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (title == null) return;
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

  Widget _card({required Widget child, Key? key}) => Material(
    key: key,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final collections = provider.journalCollections;
    final currentCollection = collections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    final query = _query.trim().toLowerCase();
    final entries = provider.journalEntries.where((entry) {
      final inScope = widget.collectionId != null
          ? entry.collectionId == widget.collectionId
          : query.isNotEmpty ||
                entry.collectionId == null ||
                !collections.any((c) => c.id == entry.collectionId);
      return inScope &&
          (query.isEmpty ||
              entry.title.toLowerCase().contains(query) ||
              entry.tags.any((tag) => tag.toLowerCase().contains(query)));
    }).toList();
    final sections = widget.collectionId == null && query.isEmpty;
    final notes = <Widget>[
      if (sections && entries.isNotEmpty) _heading('零散笔记'),
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _card(
            key: ValueKey('note-card-${entry.id}'),
            child: ListTile(
              visualDensity: const VisualDensity(vertical: -2),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                entry.title.isEmpty ? '未命名' : entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Row(
                children: [
                  Flexible(
                    flex: 3,
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
                    Flexible(
                      flex: 2,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: JournalTags(tags: entry.tags, compact: true),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () => _open(entry),
              onLongPress: () => _delete(entry),
            ),
          ),
        ),
    ];
    final folders = <Widget>[
      if (sections && collections.isNotEmpty) _heading('笔记合集'),
      if (sections)
        for (final folder in collections)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _card(
              key: ValueKey('note-folder-${folder.id}'),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  folder.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${provider.journalEntries.where((e) => e.collectionId == folder.id).length} 条记录',
                ),
                trailing: const Icon(Icons.chevron_right),
                onLongPress: () => _collection(folder),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: JournalPage(collectionId: folder.id),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(currentCollection?.title ?? '记录'),
        actions: [
          if (widget.collectionId == null)
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
          Expanded(
            child: notes.isEmpty && folders.isEmpty
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
                    children: provider.looseNotesFirst
                        ? [...notes, ...folders]
                        : [...folders, ...notes],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
    ),
  );
}
