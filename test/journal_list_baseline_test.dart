import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_quill/src/editor/widgets/proxy.dart';
import 'package:inch_light/widgets/journal_body.dart';

void main() {
  testWidgets(
    'Adding English to a Han list item preserves row baselines and height',
    (t) async {
      var hasFonts = false;
      if (File('C:/Windows/Fonts/msyh.ttc').existsSync()) {
        for (final (family, path) in [
          (
            'ListLatin',
            'C:/Users/CJZ/.cache/inch-light-tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ),
          ('ListHan', 'C:/Windows/Fonts/msyh.ttc'),
        ]) {
          await t.runAsync(() async {
            final loader = FontLoader(family)
              ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
            await loader.load();
          });
        }
        hasFonts = true;
      }
      final defaults = journalStyles(lineHeight: 1.5);
      final style = defaults.lists!.style.copyWith(
        fontFamily: hasFonts ? 'ListLatin' : null,
        fontFamilyFallback: hasFonts ? ['ListHan'] : null,
      );
      final styles = q.DefaultStyles(
        lists: defaults.lists!.copyWith(style: style),
        paragraph: defaults.paragraph!.copyWith(style: style),
      );
      for (final type in ['bullet', 'ordered', 'unchecked', 'checked']) {
        final c = q.QuillController(
          document: q.Document.fromJson([
            {'insert': '纯中文列表项'},
            {
              'insert': '\n',
              'attributes': {'list': type},
            },
            {
              'insert': '较大字号',
              'attributes': {'size': '26'},
            },
            {
              'insert': '\n',
              'attributes': {'list': type},
            },
            {'insert': '后续正文\n'},
          ]),
          selection: const TextSelection.collapsed(offset: 6),
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: q.QuillEditor.basic(
                controller: c,
                config: q.QuillEditorConfig(
                  customStyles: styles,
                  showCursor: false,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        List<(double, double)> metrics() => t
            .renderObjectList<RenderParagraphProxy>(find.byType(RichTextProxy))
            .map(
              (proxy) => (
                proxy
                    .localToGlobal(
                      Offset(
                        0,
                        proxy.child!.getDryBaseline(
                          proxy.child!.constraints,
                          TextBaseline.alphabetic,
                        )!,
                      ),
                    )
                    .dy,
                proxy.size.height,
              ),
            )
            .toList();
        final before = metrics();
        c.replaceText(
          6,
          0,
          ' English',
          const TextSelection.collapsed(offset: 14),
        );
        await t.pumpAndSettle();
        final after = metrics();
        expect(after.length, before.length);
        for (var i = 0; i < before.length; i++) {
          expect(
            after[i].$1,
            closeTo(before[i].$1, .01),
            reason: '$type baseline $i',
          );
          expect(
            after[i].$2,
            closeTo(before[i].$2, .01),
            reason: '$type height $i',
          );
        }
        final proxies = t
            .widgetList<RichTextProxy>(find.byType(RichTextProxy))
            .toList();
        expect(proxies.first.strutStyle.forceStrutHeight, true);
        expect(proxies[1].strutStyle.fontSize, 26);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        c.dispose();
      }
    },
  );
}
