import 'dart:math' as math;
import '../utils/journal_image_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../models/journal_table.dart';
import '../widgets/journal_body.dart';
import '../widgets/journal_tags.dart';
import '../widgets/journal_export_icon.dart';
import '../widgets/journal_image_settings.dart';
import '../utils/journal_operations.dart';

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
  bool _ready = false;
  JournalImageSettings _settings = JournalImageSettings();

  Future<void> _configure() async {
    final settings = await showDialog<JournalImageSettings>(
      context: context,
      builder: (_) => JournalImageSettingsDialog(settings: _settings),
    );
    if (!mounted || settings == null) return;
    final previous = _controller.document;
    setState(() {
      _settings = settings;
      _controller.document = quill.Document.fromJson(
        journalImageDocument(widget.entry.document, settings.indent),
      );
    });
    previous.close();
  }

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: quill.Document.fromJson(widget.entry.document),
      selection: const TextSelection.collapsed(offset: 0),
    )..readOnly = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await JournalImageSettings.load();
    if (!mounted) return;
    final previous = _controller.document;
    setState(() {
      _settings = settings;
      _controller.document = quill.Document.fromJson(
        journalImageDocument(widget.entry.document, settings.indent),
      );
      _ready = true;
    });
    previous.close();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _export(bool share) async {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await captureJournalPng(boundary, pixelRatio);
      final result = await const MethodChannel('inch_light/note_export')
          .invokeMethod<bool>(share ? 'shareImage' : 'saveImage', {
            'bytes': bytes,
            'name': widget.entry.title.trim().isEmpty
                ? '笔记'
                : widget.entry.title.trim(),
          });
      if (result == true) {
        await _settings.saveImage();
        if (mounted) Navigator.of(context).pop();
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
          columns *
                  ((MediaQuery.textScalerOf(context).scale(_settings.fontSize) +
                              _settings.letterSpacing) *
                          5 +
                      16) +
              _settings.sideMargin * 2,
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
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('导出长图'),
          actions: [
            IconButton(
              tooltip: '图片设置',
              onPressed: (_busy || !_ready) ? null : _configure,
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              tooltip: '分享图片',
              onPressed: (_busy || !_ready) ? null : () => _export(true),
              icon: const JournalActionIcon(JournalActionSymbol.share),
            ),
            IconButton(
              tooltip: '保存图片',
              onPressed: (_busy || !_ready) ? null : () => _export(false),
              icon: const JournalActionIcon(JournalActionSymbol.saveImage),
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
                        key: const ValueKey('image-page-padding'),
                        padding: EdgeInsets.fromLTRB(
                          _settings.sideMargin,
                          _settings.topMargin,
                          _settings.sideMargin,
                          _settings.bottomMargin,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.entry.title.isNotEmpty) ...[
                              Text(
                                widget.entry.title,
                                style: TextStyle(
                                  fontSize: _settings.fontSize * 30 / 18,
                                  letterSpacing: _settings.letterSpacing,
                                  height: 1.4,
                                  color: const Color(0xFF3D3D3D),
                                  fontWeight: widget.entry.titleBold
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (!_settings.hideMetadata)
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
                                customStyles: journalStyles(
                                  fontSize: _settings.fontSize,
                                  letterSpacing: _settings.letterSpacing,
                                  lineHeight: _settings.lineHeight,
                                  paragraphSpacing: _settings.paragraphSpacing,
                                ),
                                textSpanBuilder: journalSpan,
                                // ignore: experimental_member_use
                                customLeadingBlockBuilder: (node, config) =>
                                    journalLeading(
                                      context,
                                      node,
                                      config,
                                      readOnly: true,
                                      textStyle:
                                          journalBlock(
                                            _settings.fontSize,
                                          ).style.copyWith(
                                            letterSpacing:
                                                _settings.letterSpacing,
                                            height: _settings.lineHeight,
                                          ),
                                    ),
                                embedBuilders: [
                                  const JournalDividerBuilder(),
                                  JournalTableBuilder(
                                    onChanged: (_) {},
                                    fontSize: _settings.fontSize,
                                    letterSpacing: _settings.letterSpacing,
                                    lineHeight: _settings.lineHeight,
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
    ),
  );
}
