import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import 'main_screen.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final entries = provider.journalEntries.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final children = <Widget>[];
    String? previousDay;
    for (final entry in entries) {
      final day = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      if (day != previousDay) {
        if (previousDay != null) {
          children.add(const Divider(color: Color(0xFFDDDDDD), height: 32));
        }
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
          ),
        );
        previousDay = day;
      }
      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('HH:mm:ss').format(entry.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 10),
              MarkdownBody(data: entry.content, selectable: true),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('记录'),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showGlobalSettingsDialog(context, provider),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                '点击右下角，记下此刻',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: children,
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'journal-add',
        backgroundColor: AppColors.primary,
        onPressed: () {
          final capturedAt = DateTime.now();
          showDialog(
            context: context,
            builder: (_) => _JournalEditor(
              capturedAt: capturedAt,
              onSave: (text) => provider.addJournalEntry(text, capturedAt),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _JournalEditor extends StatefulWidget {
  final DateTime capturedAt;
  final ValueChanged<String> onSave;
  const _JournalEditor({required this.capturedAt, required this.onSave});
  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  final _controller = TextEditingController();
  bool _preview = false;
  void _insert(String prefix, [String suffix = '']) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = text.substring(start, end);
    final linePrefix = suffix.isEmpty && start > 0 && text[start - 1] != '\n'
        ? '\n$prefix'
        : prefix;
    final replacement = '$linePrefix$selected$suffix';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(
        offset: start + linePrefix.length + selected.length,
      ),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('记录此刻'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.capturedAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            Wrap(
              children: [
                for (var level = 1; level <= 3; level++)
                  TextButton(
                    onPressed: () => _insert('${'#' * level} '),
                    child: Text('H$level'),
                  ),
                IconButton(
                  tooltip: '加粗',
                  onPressed: () => _insert('**', '**'),
                  icon: const Icon(Icons.format_bold),
                ),
                IconButton(
                  tooltip: '斜体',
                  onPressed: () => _insert('*', '*'),
                  icon: const Icon(Icons.format_italic),
                ),
                IconButton(
                  tooltip: '列表',
                  onPressed: () => _insert('- '),
                  icon: const Icon(Icons.format_list_bulleted),
                ),
                IconButton(
                  tooltip: _preview ? '继续编辑' : '预览',
                  onPressed: () => setState(() => _preview = !_preview),
                  icon: Icon(_preview ? Icons.edit : Icons.visibility),
                ),
              ],
            ),
            if (_preview)
              MarkdownBody(
                data: _controller.text.isEmpty ? '暂无内容' : _controller.text,
              )
            else
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 6,
                maxLines: 12,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '写下此刻，支持 Markdown…',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () {
                widget.onSave(_controller.text);
                Navigator.pop(context);
              },
        child: const Text('确定'),
      ),
    ],
  );
}
