import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../models/journal_table.dart';
import '../widgets/journal_body.dart';
import '../widgets/journal_tags.dart';

class JournalImagePage extends StatefulWidget {
  const JournalImagePage({super.key, required this.entry});
  final JournalEntry entry;
  @override
  State<JournalImagePage> createState() => _JournalImagePageState();
}

class _JournalImagePageState extends State<JournalImagePage> {
  final _capture = GlobalKey();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final quill.QuillController _controller;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: quill.Document.fromJson(widget.entry.document),
      selection: const TextSelection.collapsed(offset: 0),
    )..readOnly = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _export(bool share) async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // Keep complete content while bounding pixel dimensions and peak memory.
      final size = boundary.size;
      final ratio = math.min(
        2.0,
        math.min(
          16000 / size.height,
          math.sqrt(24000000 / (size.width * size.height)),
        ),
      );
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('图片生成失败');
      final result = await const MethodChannel('inch_light/note_export')
          .invokeMethod<bool>(share ? 'shareImage' : 'saveImage', {
            'bytes': bytes.buffer.asUint8List(),
            'name': widget.entry.title.trim().isEmpty
                ? '笔记'
                : widget.entry.title.trim(),
          });
      if (mounted && result == true && !share) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片已保存')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片导出失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double _imageWidth(BuildContext context) {
    var width = MediaQuery.sizeOf(context).width;
    for (final op in widget.entry.document) {
      final insert = op['insert'];
      if (insert is Map && insert['table'] is String) {
        final columns = JournalTableData.decode(insert['table']).columns;
        width = math.max(
          width,
          columns * (MediaQuery.textScalerOf(context).scale(18) * 5 + 16) + 48,
        );
      }
    }
    return width;
  }

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    locale: const Locale('zh'),
    delegates: quill.FlutterQuillLocalizations.localizationsDelegates,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('导出长图'),
        actions: [
          IconButton(
            tooltip: '分享图片',
            onPressed: _busy ? null : () => _export(true),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: '保存图片',
            onPressed: _busy ? null : () => _export(false),
            icon: const Icon(Icons.save_alt),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _imageWidth(context),
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _capture,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.entry.title.isNotEmpty) ...[
                            Text(
                              widget.entry.title,
                              style: TextStyle(
                                fontSize: 30,
                                height: 1.4,
                                color: const Color(0xFF3D3D3D),
                                fontWeight: widget.entry.titleBold
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            '${DateFormat('M月d日 HH:mm').format(widget.entry.updatedAt)}  |  ${widget.entry.wordCount}字',
                            key: const ValueKey('image-metadata'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF999999),
                            ),
                          ),
                          if (widget.entry.tags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            JournalTags(tags: widget.entry.tags),
                          ],
                          const SizedBox(height: 20),
                          quill.QuillEditor(
                            controller: _controller,
                            focusNode: _focus,
                            scrollController: _scroll,
                            config: quill.QuillEditorConfig(
                              scrollable: false,
                              padding: EdgeInsets.zero,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              customStyles: journalStyles(),
                              textSpanBuilder: journalSpan,
                              // ignore: experimental_member_use
                              customLeadingBlockBuilder: (node, config) =>
                                  journalLeading(
                                    context,
                                    node,
                                    config,
                                    readOnly: true,
                                  ),
                              embedBuilders: [
                                const JournalDividerBuilder(),
                                JournalTableBuilder(onChanged: (_) {}),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    ),
  );
}
