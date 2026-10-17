import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/journal_image_settings.dart';
import '../widgets/journal_chain_dialog.dart';
import '../utils/clipboard.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_tags.dart';
import '../providers/app_provider.dart';
import '../utils/journal_markdown.dart';
import '../utils/journal_shortcuts.dart';
import '../utils/journal_operations.dart';
import '../utils/journal_controller.dart';
import '../widgets/journal_body.dart';
import '../widgets/journal_export_icon.dart';
import 'journal_image_page.dart';
import '../models/journal_table.dart';
import '../widgets/journal_table.dart';
import '../widgets/journal_format_icon.dart';

class JournalEditorPage extends StatefulWidget {
  const JournalEditorPage({super.key, this.entry, this.collectionId});
  final JournalEntry? entry;
  final String? collectionId;

  @override
  State<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends State<JournalEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final JournalController _editor;
  late final AppProvider _provider;
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _bodyScroll = ScrollController();
  final _pageScroll = ScrollController();
  final _renderEditorKey = GlobalKey<quill.EditorState>();
  final _pageViewportKey = GlobalKey();
  final _tableKeys = <String, GlobalKey>{};
  bool _caretScrollPending = false;
  bool _titleBold = false;
  late final String _id;
  late final DateTime _createdAt;
  late DateTime _updatedAt;
  late List<String> _tags;
  final List<String> _undo = [];
  final List<String> _redo = [];
  late String _current;
  String? _saved;
  Timer? _saveTimer;
  bool _restoring = false;
  bool _shortcutPending = false;
  bool _leaving = false;
  String? _newTableId;
  JournalImageSettings _pageStyle = JournalImageSettings(
    topMargin: 16,
    bottomMargin: 32,
  );
  List<JournalOperation> _chain = [];

  Future<void> _loadPreferences() async {
    final style = await JournalImageSettings.load(page: true);
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('journal_operation_chain') ?? [];
    if (!mounted) return;
    setState(() {
      _pageStyle = style;
      _chain = names
          .expand(
            (name) => JournalOperation.values.where((op) => op.name == name),
          )
          .toList();
    });
  }

  void _stayBrowsing() {
    // Disable route focus restoration until an explicit tap in the note.
    _titleFocus.canRequestFocus = false;
    _bodyFocus.canRequestFocus = false;
    FocusScope.of(context).unfocus();
    _editor.skipRequestKeyboard = true;
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<void> _configurePage() async {
    _stayBrowsing();
    final next = await showDialog<JournalImageSettings>(
      context: context,
      builder: (_) =>
          JournalImageSettingsDialog(settings: _pageStyle, page: true),
    );
    if (!mounted || next == null) return;
    try {
      await next.savePage(_pageStyle);
      if (mounted) setState(() => _pageStyle = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('页面设置保存失败，请重试')));
      }
    }
  }

  Future<void> _editChain() async {
    _stayBrowsing();
    final next = await showDialog<List<JournalOperation>>(
      context: context,
      builder: (_) => JournalChainDialog(operations: _chain),
    );
    if (!mounted || next == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setStringList(
      'journal_operation_chain',
      next.map((op) => op.name).toList(),
    );
    if (!mounted) return;
    if (saved) {
      setState(() => _chain = next);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('连携操作保存失败，请重试')));
    }
  }

  Future<void> _punctuationMenu() async {
    _stayBrowsing();
    final operation = await showDialog<JournalOperation>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('标点管理'),
        children: [
          for (final op in [
            JournalOperation.removeLeadingPunctuation,
            JournalOperation.addSentencePeriods,
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, op),
              child: Text(journalOperationName(op)),
            ),
        ],
      ),
    );
    if (mounted && operation != null) await _operate(operation);
  }

  Future<void> _runChain() async {
    if (_chain.isEmpty) {
      await _editChain();
      return;
    }
    await _operate(_chain.first, chain: _chain);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<AppProvider>();
    _id = widget.entry?.id ?? const Uuid().v4();
    _createdAt = widget.entry?.createdAt ?? DateTime.now();
    _updatedAt = widget.entry?.updatedAt ?? _createdAt;
    _tags = List.from(widget.entry?.tags ?? []);
    _titleBold = widget.entry?.titleBold ?? false;
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _editor = JournalController(
      config: const quill.QuillControllerConfig(
        // Quill is pinned; plain-text external paste prevents unsupported image
        // embeds from entering records. Recheck this API when upgrading Quill.
        // ignore: experimental_member_use
        clipboardConfig: quill.QuillClipboardConfig(
          // ignore: experimental_member_use
          enableExternalRichPaste: false,
        ),
      ),
      document: widget.entry == null
          ? quill.Document()
          : quill.Document.fromJson(widget.entry!.document),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _current = _snapshot();
    _saved = _current;
    _title.addListener(_changed);
    _editor.addListener(_changed);
    _titleFocus.addListener(_refreshFocus);
    _bodyFocus.addListener(_refreshFocus);
    _loadPreferences();
  }

  void _refreshFocus() {
    if (mounted) setState(() {});
    _revealCaret();
  }

  @override
  void didChangeMetrics() => _revealCaret();

  void _revealCaret() {
    if (_caretScrollPending || !mounted || !_bodyFocus.hasPrimaryFocus) return;
    _caretScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _caretScrollPending = false;
      if (!mounted ||
          !_bodyFocus.hasPrimaryFocus ||
          !_pageScroll.hasClients ||
          !_editor.selection.isCollapsed) {
        return;
      }
      final editor = _renderEditorKey.currentState?.renderEditor;
      final viewport = _pageViewportKey.currentContext?.findRenderObject();
      if (editor == null || viewport is! RenderBox || !viewport.hasSize) return;
      final caret = editor.getLocalRectForCaret(
        TextPosition(
          offset: _editor.selection.extentOffset.clamp(
            0,
            _editor.document.length - 1,
          ),
        ),
      );
      final top = viewport
          .globalToLocal(editor.localToGlobal(caret.topLeft))
          .dy;
      final bottom = viewport
          .globalToLocal(editor.localToGlobal(caret.bottomRight))
          .dy;
      const margin = 16.0;
      final shift = bottom > viewport.size.height - margin
          ? bottom - viewport.size.height + margin
          : top < margin
          ? top - margin
          : 0.0;
      if (shift.abs() < .5) return;
      // The parent viewport already excludes the keyboard and format bar.
      // Jump once after layout so repeated returns cannot race scroll animations.
      final target = (_pageScroll.offset + shift).clamp(
        0.0,
        _pageScroll.position.maxScrollExtent,
      );
      _pageScroll.jumpTo(target);
    });
  }

  String _snapshot() => jsonEncode({
    'title': _title.text,
    'document': _editor.document.toDelta().toJson(),
    'tags': _tags,
    'titleBold': _titleBold,
  });

  JournalEntry _entry() => JournalEntry(
    id: _id,
    title: _title.text,
    document: _editor.document.toDelta().toJson(),
    createdAt: _createdAt,
    updatedAt: _updatedAt,
    tags: List.from(_tags),
    collectionId: widget.entry?.collectionId ?? widget.collectionId,
    isPinned: widget.entry?.isPinned ?? false,
    titleBold: _titleBold,
    isBottom: widget.entry?.isBottom ?? false,
  );

  void _changed() {
    if (_restoring) return;
    final next = _snapshot();
    if (next != _current) {
      _undo.add(_current);
      if (_undo.length > 200) _undo.removeAt(0);
      _redo.clear();
      _current = next;
      _updatedAt = DateTime.now();
      _scheduleSave();
      if (_bodyFocus.hasPrimaryFocus && !_shortcutPending) {
        _shortcutPending = true;
        scheduleMicrotask(() {
          _shortcutPending = false;
          if (!mounted || !_bodyFocus.hasPrimaryFocus || _restoring) return;
          _restoring = true;
          var changed = false;
          try {
            changed = applyJournalShortcut(_editor);
          } finally {
            _restoring = false;
          }
          if (changed) _changed();
        });
      }
    }
    // Cursor movements also refresh the active format indicators.
    if (mounted) setState(() {});
    _revealCaret();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _save);
  }

  Future<bool> _save() async {
    _saveTimer?.cancel();
    final snapshot = _current;
    if (snapshot == _saved) return true;
    final entry = _entry();
    if (widget.entry == null &&
        !_provider.journalEntries.any((e) => e.id == _id) &&
        entry.title.trim().isEmpty &&
        entry.content.trim().isEmpty &&
        entry.tags.isEmpty &&
        !_editor.document.toDelta().toJson().any((op) => op['insert'] is Map)) {
      return true;
    }
    try {
      await _provider.saveJournalEntry(entry);
      _saved = snapshot;
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('保存失败，请重试'),
              duration: Duration(milliseconds: 1500),
            ),
          );
      }
      return false;
    }
  }

  void _history(bool redo) {
    if (!_bodyFocus.hasFocus && !_titleFocus.hasFocus) _stayBrowsing();
    final source = redo ? _redo : _undo;
    final target = redo ? _undo : _redo;
    if (source.isEmpty) return;
    target.add(_current);
    _current = source.removeLast();
    final data = jsonDecode(_current) as Map<String, dynamic>;
    final selection = _editor.selection;
    final titleSelection = _title.selection;
    _restoring = true;
    _title.value = TextEditingValue(
      text: data['title'] as String,
      selection: TextSelection.collapsed(
        offset: titleSelection.extentOffset.clamp(
          0,
          (data['title'] as String).length,
        ),
      ),
    );
    final skipKeyboard = !_bodyFocus.hasFocus;
    _editor.skipRequestKeyboard = skipKeyboard;
    final oldDocument = _editor.document;
    _editor.document = quill.Document.fromJson(data['document'] as List);
    _editor.skipRequestKeyboard = skipKeyboard;
    _editor.updateSelection(
      TextSelection.collapsed(
        offset: selection.extentOffset.clamp(0, _editor.document.length - 1),
      ),
      quill.ChangeSource.local,
    );
    oldDocument.close();
    _tags = (data['tags'] as List).cast<String>();
    _titleBold = data['titleBold'] as bool? ?? false;
    _restoring = false;
    _updatedAt = DateTime.now();
    _scheduleSave();
    setState(() {});
  }

  Future<void> _finish() async {
    if (await _save() && mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _insertTable() async {
    final selection = _editor.selection;
    FocusScope.of(context).unfocus();
    final table = await showJournalTableDialog(context);
    if (!mounted || table == null) return;
    _newTableId = table.id;
    _editor.skipRequestKeyboard = true;
    _editor.insertTable(table, selection);
  }

  void _updateTable(JournalTableData table) {
    var offset = 0;
    for (final op in _editor.document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map &&
          insert['table'] is String &&
          JournalTableData.decode(insert['table']).id == table.id) {
        _editor.skipRequestKeyboard = true;
        _editor.replaceText(
          offset,
          1,
          quill.BlockEmbed('table', table.encode()),
          null,
        );
        return;
      }
      offset += insert is String ? insert.length : 1;
    }
  }

  Future<void> _deleteTable(String id) async {
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除整张表格？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    _newTableId = null;
    if (_editor.deleteTable(id)) _bodyFocus.requestFocus();
  }

  Future<void> _operate(
    JournalOperation operation, {
    List<JournalOperation>? chain,
  }) async {
    _stayBrowsing();
    final operations = chain ?? [operation];
    List<dynamic> document = _editor.document.toDelta().toJson();
    var title = _title.text;
    for (final op in operations) {
      document = transformJournalDocument(document, op);
      title = transformJournalText(title, op);
    }
    final before = _current;
    _restoring = true;
    final previous = _editor.document;
    _editor.skipRequestKeyboard = true;
    _editor.document = quill.Document.fromJson(document);
    // Quill consumes this flag on each notification, including document replacement.
    _editor.skipRequestKeyboard = true;
    _editor.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
    previous.close();
    _title.text = title;
    if (operations.contains(JournalOperation.removeBold)) _titleBold = false;
    _restoring = false;
    _changed();
    if (_current == before) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有需要修改的内容')));
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            chain == null ? '已${journalOperationName(operation)}' : '已完成连携操作',
          ),
          duration: const Duration(seconds: 3),
          persist: false,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: '撤回', onPressed: () => _history(false)),
        ),
      );
    await _save();
  }

  Future<void> _export() async {
    _stayBrowsing();
    final choice = await showModalBottomSheet<String>(
      context: context,
      requestFocus: false,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制 Markdown'),
              onTap: () => Navigator.pop(context, 'markdown'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('导出长图'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'markdown') await _copyMarkdown();
    if (choice == 'image' && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JournalImagePage(entry: _entry()),
        ),
      );
    }
  }

  Future<void> _copyMarkdown() async {
    try {
      await copyText(journalToMarkdown(_entry()));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Markdown 已复制'),
              duration: Duration(milliseconds: 1500),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('复制失败，请重试'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  Future<void> _back() async {
    if (_leaving) return;
    _leaving = true;
    if (await _save() && mounted) {
      Navigator.of(context).pop();
    } else {
      _leaving = false;
    }
  }

  Future<void> _editTags() async {
    FocusScope.of(context).unfocus();
    final input = TextEditingController(text: _tags.join(' '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('标签'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(hintText: '用空格分隔多个标签'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    // Dialog routes retain their fields during the closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (!mounted || result == null) return;
    _tags = JournalEntry.parseTags(result);
    _changed();
    await _save();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _title.dispose();
    _editor.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  bool _hitTable(Offset position) {
    // Quill can map the blank line after an embed to its end offset. Hit-test
    // the rendered table instead, so that empty prose still receives focus.
    for (final key in _tableKeys.values) {
      final box = key.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          (Offset.zero & box.size).contains(box.globalToLocal(position))) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Some Android IMEs leave a one-pixel inset while their panel is hidden.
    // Ignore that residue so the toolbar cannot appear alone at screen bottom.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 48;
    return Localizations.override(
      context: context,
      locale: const Locale('zh'),
      delegates: quill.FlutterQuillLocalizations.localizationsDelegates,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            leading: IconButton(
              tooltip: '返回',
              onPressed: _back,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              if (keyboardVisible) ...[
                IconButton(
                  tooltip: '撤回',
                  onPressed: _undo.isEmpty ? null : () => _history(false),
                  icon: const JournalActionIcon(JournalActionSymbol.undo),
                ),
                IconButton(
                  tooltip: '取消撤回',
                  onPressed: _redo.isEmpty ? null : () => _history(true),
                  icon: const JournalActionIcon(JournalActionSymbol.redo),
                ),
              ],
              if (!keyboardVisible)
                IconButton(
                  tooltip: '页面设置',
                  onPressed: _configurePage,
                  icon: const Icon(Icons.tune),
                ),
              if (!keyboardVisible)
                IconButton(
                  tooltip: '导出',
                  onPressed: _export,
                  icon: const JournalExportIcon(),
                ),
              IconButton(
                tooltip: '标签',
                onPressed: _editTags,
                icon: const JournalActionIcon(JournalActionSymbol.tags),
              ),
              if (keyboardVisible)
                IconButton(
                  tooltip: '确定',
                  onPressed: _finish,
                  icon: const JournalActionIcon(JournalActionSymbol.done),
                )
              else
                PopupMenuButton<JournalOperation>(
                  tooltip: '操作',
                  icon: const Icon(Icons.more_horiz),
                  onOpened: _stayBrowsing,
                  requestFocus: false,
                  onSelected: (operation) =>
                      operation == JournalOperation.removeLeadingPunctuation
                      ? _punctuationMenu()
                      : _operate(operation),
                  itemBuilder: (menuContext) => [
                    for (final operation in JournalOperation.values.where(
                      (op) => op != JournalOperation.addSentencePeriods,
                    ))
                      PopupMenuItem(
                        value: operation,
                        child: Text(operation.label),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem<JournalOperation>(
                      enabled: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFEDF1F4),
                                foregroundColor: const Color(0xFF526778),
                              ),
                              icon: const Icon(Icons.playlist_play, size: 20),
                              label: const Text('连携操作'),
                              onPressed: () {
                                Navigator.pop(menuContext);
                                _runChain();
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: '编辑连携操作',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () {
                              Navigator.pop(menuContext);
                              _editChain();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Listener(
            onPointerDown: (_) {
              _titleFocus.canRequestFocus = true;
              _bodyFocus.canRequestFocus = true;
            },
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SizedBox(
                      key: _pageViewportKey,
                      child: SingleChildScrollView(
                        key: const ValueKey('record-page-scroll'),
                        controller: _pageScroll,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                _pageStyle.sideMargin,
                                _pageStyle.topMargin,
                                _pageStyle.sideMargin,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    key: const ValueKey('record-title'),
                                    controller: _title,
                                    focusNode: _titleFocus,
                                    style: TextStyle(
                                      fontSize: _pageStyle.fontSize * 30 / 18,
                                      letterSpacing: _pageStyle.letterSpacing,
                                      fontWeight: _titleBold
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                    maxLines: null,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _bodyFocus.requestFocus(),
                                    decoration: const InputDecoration(
                                      hintText: '标题',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFCCCCCC),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  if (!_pageStyle.hideMetadata)
                                    const SizedBox(height: 22),
                                  if (!_pageStyle.hideMetadata)
                                    Text(
                                      '${DateFormat('M月d日 HH:mm').format(_updatedAt)}  |  ${_entry().wordCount}字',
                                      key: const ValueKey('record-metadata'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  if (_tags.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    JournalTags(tags: _tags),
                                  ],
                                ],
                              ),
                            ),
                            quill.QuillEditor(
                              controller: _editor,
                              focusNode: _bodyFocus,
                              scrollController: _bodyScroll,
                              config: quill.QuillEditorConfig(
                                editorKey: _renderEditorKey,
                                placeholder: '开始书写',
                                padding: EdgeInsets.fromLTRB(
                                  _pageStyle.sideMargin,
                                  8,
                                  _pageStyle.sideMargin,
                                  _pageStyle.bottomMargin,
                                ),
                                scrollable: false,
                                minHeight: 180,
                                showCursor:
                                    _bodyFocus.hasPrimaryFocus &&
                                    !_editor.onEmbedLine,
                                // Pinned Quill APIs; shortcut handlers also process software-keyboard spaces.
                                // ignore: experimental_member_use
                                characterShortcutEvents:
                                    quill.standardCharactersShortcutEvents,
                                // ignore: experimental_member_use
                                spaceShortcutEvents:
                                    quill.standardSpaceShorcutEvents,
                                textSpanBuilder: journalSpan,
                                // IMEs may send a key event at offset zero instead of a text replacement.
                                // ignore: experimental_member_use
                                onKeyPressed: (event, _) {
                                  if (_bodyFocus.hasPrimaryFocus &&
                                      (event is KeyDownEvent ||
                                          event is KeyRepeatEvent) &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.backspace &&
                                      (_editor.clearLeadingEmptyLines() ||
                                          _editor.handleTableBackspace())) {
                                    return KeyEventResult.handled;
                                  }
                                  return null;
                                },
                                // ignore: experimental_member_use
                                customLeadingBlockBuilder: (node, config) =>
                                    journalLeading(
                                      context,
                                      node,
                                      config,
                                      textStyle:
                                          journalBlock(
                                            _pageStyle.fontSize,
                                          ).style.copyWith(
                                            letterSpacing:
                                                _pageStyle.letterSpacing,
                                            height: _pageStyle.lineHeight,
                                          ),
                                    ),
                                // Embedded cells own their caret; Quill must not reclaim focus on tap.
                                onTapUp: (details, _) {
                                  final table = _hitTable(
                                    details.globalPosition,
                                  );
                                  if (!table) {
                                    _editor.skipRequestKeyboard = false;
                                  }
                                  return table;
                                },
                                onTapOutsideEnabled: false,
                                embedBuilders: [
                                  const JournalDividerBuilder(),
                                  JournalTableBuilder(
                                    tableKeys: _tableKeys,
                                    fontSize: _pageStyle.fontSize,
                                    letterSpacing: _pageStyle.letterSpacing,
                                    lineHeight: _pageStyle.lineHeight,
                                    onChanged: _updateTable,
                                    onDelete: _deleteTable,
                                    onMoveDown: (id) =>
                                        _editor.moveTableDown(id),
                                    autofocusId: _newTableId,
                                    selectedOffset:
                                        _editor.selection.isCollapsed
                                        ? null
                                        : _editor.pendingTable,
                                  ),
                                ],
                                customStyles: journalStyles(
                                  fontSize: _pageStyle.fontSize,
                                  letterSpacing: _pageStyle.letterSpacing,
                                  lineHeight: _pageStyle.lineHeight,
                                  paragraphSpacing: _pageStyle.paragraphSpacing,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (keyboardVisible)
                    JournalFormatBar(
                      controller: _editor,
                      onFormat: () => _bodyFocus.requestFocus(),
                      onTable: _insertTable,
                      titleBold: _titleFocus.hasFocus ? _titleBold : null,
                      onTitleBold: () {
                        _titleBold = !_titleBold;
                        _changed();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JournalFormatBar extends StatelessWidget {
  const JournalFormatBar({
    super.key,
    required this.controller,
    required this.onFormat,
    required this.onTable,
    this.titleBold,
    this.onTitleBold,
  });
  final quill.QuillController controller;
  final VoidCallback onFormat;
  final VoidCallback onTable;
  final bool? titleBold;
  final VoidCallback? onTitleBold;

  bool _active(quill.Attribute attribute) {
    if (attribute == quill.Attribute.bold && titleBold != null) {
      return titleBold!;
    }
    final value = controller
        .getSelectionStyle()
        .attributes[attribute.key]
        ?.value;
    if (attribute == quill.Attribute.leftAlignment) {
      return value == null || value == 'left';
    }
    return value == attribute.value;
  }

  void _format(quill.Attribute attribute) {
    final isAlignment = attribute.key == quill.Attribute.align.key;
    controller.formatSelection(
      !isAlignment && _active(attribute)
          ? quill.Attribute.clone(attribute, null)
          : attribute,
    );
    onFormat();
  }

  void _divider() {
    final selection = controller.selection;
    controller.replaceText(
      selection.start,
      selection.end - selection.start,
      const quill.BlockEmbed('divider', 'hr'),
      null,
    );
    // Quill may add a leading newline when inserting inside a paragraph.
    // Locate the actual embed instead of assuming its offset, and ensure that
    // there is a separate editable paragraph after a divider at the end.
    var offset = 0;
    var nextLine = selection.start;
    for (final op in controller.document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is Map && offset >= selection.start) {
        nextLine = offset + 2;
        break;
      }
      offset += insert is String ? insert.length : 1;
    }
    if (nextLine >= controller.document.length) {
      controller.replaceText(controller.document.length - 1, 0, '\n', null);
    }
    controller.updateSelection(
      TextSelection.collapsed(
        offset: nextLine.clamp(0, controller.document.length - 1),
      ),
      quill.ChangeSource.local,
    );
    onFormat();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth / 7;
      Widget button(
        String label,
        Widget icon, {
        quill.Attribute? attribute,
        VoidCallback? action,
      }) {
        final selected = attribute != null && _active(attribute);
        return SizedBox(
          width: width,
          height: 54,
          child: Semantics(
            selected: selected,
            child: IconButton(
              key: ValueKey('format-$label'),
              tooltip: label,
              onPressed: action ?? () => _format(attribute!),
              style: IconButton.styleFrom(
                iconSize: 24,
                backgroundColor: selected
                    ? const Color(0xFFEDEDED)
                    : Colors.transparent,
                foregroundColor: AppColors.textDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              icon: SizedBox.square(dimension: 26, child: Center(child: icon)),
            ),
          ),
        );
      }

      return Material(
        color: Colors.white,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: SingleChildScrollView(
            key: const ValueKey('record-format-scroll'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                button(
                  '一级标题',
                  const JournalFormatIcon(JournalFormatSymbol.h1),
                  attribute: quill.Attribute.h1,
                ),
                button(
                  '二级标题',
                  const JournalFormatIcon(JournalFormatSymbol.h2),
                  attribute: quill.Attribute.h2,
                ),
                button(
                  '三级标题',
                  const JournalFormatIcon(JournalFormatSymbol.h3),
                  attribute: quill.Attribute.h3,
                ),
                button(
                  '加粗',
                  const JournalFormatIcon(JournalFormatSymbol.bold),
                  attribute: quill.Attribute.bold,
                  action: titleBold == null ? null : onTitleBold,
                ),
                button(
                  '引用',
                  const Icon(Icons.format_quote),
                  attribute: quill.Attribute.blockQuote,
                ),
                button(
                  '有序列表',
                  const Icon(Icons.format_list_numbered),
                  attribute: quill.Attribute.ol,
                ),
                button(
                  '无序列表',
                  const JournalFormatIcon(JournalFormatSymbol.bullet),
                  attribute: quill.Attribute.ul,
                ),
                button(
                  '倾斜',
                  const JournalFormatIcon(JournalFormatSymbol.italic),
                  attribute: quill.Attribute.italic,
                ),
                button(
                  '删除线',
                  const JournalFormatIcon(JournalFormatSymbol.strike),
                  attribute: quill.Attribute.strikeThrough,
                ),
                button(
                  '下划线',
                  const JournalFormatIcon(JournalFormatSymbol.underline),
                  attribute: quill.Attribute.underline,
                ),
                button(
                  '高亮',
                  const JournalFormatIcon(JournalFormatSymbol.highlight),
                  attribute: const quill.BackgroundAttribute('#FFF2B3'),
                ),
                button(
                  '分隔线',
                  const JournalFormatIcon(JournalFormatSymbol.divider),
                  action: _divider,
                ),
                button(
                  '上标',
                  const JournalFormatIcon(JournalFormatSymbol.superscript),
                  attribute: quill.Attribute.superscript,
                ),
                button(
                  '下标',
                  const JournalFormatIcon(JournalFormatSymbol.subscript),
                  attribute: quill.Attribute.subscript,
                ),
                button(
                  '行内代码',
                  const JournalFormatIcon(JournalFormatSymbol.code),
                  attribute: quill.Attribute.inlineCode,
                ),
                button(
                  '表格',
                  const JournalFormatIcon(JournalFormatSymbol.table),
                  action: onTable,
                ),
                button(
                  '居中对齐',
                  const JournalFormatIcon(JournalFormatSymbol.alignCenter),
                  attribute: quill.Attribute.centerAlignment,
                ),
                button(
                  '左对齐',
                  const JournalFormatIcon(JournalFormatSymbol.alignLeft),
                  attribute: quill.Attribute.leftAlignment,
                ),
                button(
                  '右对齐',
                  const JournalFormatIcon(JournalFormatSymbol.alignRight),
                  attribute: quill.Attribute.rightAlignment,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
