import 'package:flutter/material.dart';

class JournalImageSettings {
  JournalImageSettings({
    this.fontSize = 18,
    this.letterSpacing = 0,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 8,
    this.indent = false,
    this.hideMetadata = false,
    this.topMargin = 54,
    this.bottomMargin = 54,
    this.sideMargin = 24,
  });
  double fontSize;
  double letterSpacing;
  double lineHeight;
  double paragraphSpacing;
  bool indent;
  bool hideMetadata;
  double topMargin;
  double bottomMargin;
  double sideMargin;
  JournalImageSettings copy() => JournalImageSettings(
    fontSize: fontSize,
    letterSpacing: letterSpacing,
    lineHeight: lineHeight,
    paragraphSpacing: paragraphSpacing,
    indent: indent,
    hideMetadata: hideMetadata,
    topMargin: topMargin,
    bottomMargin: bottomMargin,
    sideMargin: sideMargin,
  );
}

class JournalImageSettingsDialog extends StatefulWidget {
  const JournalImageSettingsDialog({super.key, required this.settings});
  final JournalImageSettings settings;
  @override
  State<JournalImageSettingsDialog> createState() =>
      _JournalImageSettingsDialogState();
}

class _JournalImageSettingsDialogState
    extends State<JournalImageSettingsDialog> {
  late final value = widget.settings.copy();
  Widget _slider(
    String label,
    double current,
    double min,
    double max,
    int divisions,
    ValueChanged<double> update, {
    String suffix = '',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label  ${current.toStringAsFixed(current == current.roundToDouble() ? 0 : 1)}$suffix',
      ),
      Slider(
        key: ValueKey('image-$label'),
        value: current,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: (next) => setState(() => update(next)),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('图片设置'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slider(
              '字号',
              value.fontSize,
              12,
              32,
              20,
              (v) => value.fontSize = v,
            ),
            _slider(
              '字间距',
              value.letterSpacing,
              0,
              6,
              12,
              (v) => value.letterSpacing = v,
            ),
            _slider(
              '行间距',
              value.lineHeight,
              1,
              2.5,
              15,
              (v) => value.lineHeight = v,
              suffix: ' 倍',
            ),
            _slider(
              '段间距',
              value.paragraphSpacing,
              0,
              40,
              20,
              (v) => value.paragraphSpacing = v,
            ),
            _slider(
              '顶部留白',
              value.topMargin,
              0,
              120,
              60,
              (v) => value.topMargin = v,
            ),
            _slider(
              '底部留白',
              value.bottomMargin,
              0,
              120,
              60,
              (v) => value.bottomMargin = v,
            ),
            _slider(
              '两侧留白',
              value.sideMargin,
              0,
              80,
              40,
              (v) => value.sideMargin = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('开头空两格'),
              value: value.indent,
              onChanged: (v) => setState(() => value.indent = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('隐藏编辑时间与字数'),
              value: value.hideMetadata,
              onChanged: (v) => setState(() => value.hideMetadata = v),
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
      TextButton(
        onPressed: () => Navigator.pop(context, value),
        child: const Text('完成'),
      ),
    ],
  );
}
