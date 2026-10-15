import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:inch_light/models/journal_table.dart';
import 'package:inch_light/utils/journal_controller.dart';

void main() {
  test('Move table inserts a blank paragraph and preserves data and undo', () {
    for (final prefix in ['', '前文\n', '前文\n\n']) {
      final table = JournalTableData.empty(3, 2);
      final c = JournalController(
        document: quill.Document.fromJson([
          if (prefix.isNotEmpty) {'insert': prefix},
          {
            'insert': {'table': table.encode()},
          },
          {'insert': '\n后文\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      final before = c.document.toDelta().toJson();
      expect(c.moveTableDown('missing'), isFalse);
      expect(c.document.toDelta().toJson(), before);
      expect(c.moveTableDown(table.id), isTrue);
      expect(c.document.toPlainText(), '$prefix\n\uFFFC\n后文\n');
      expect(
        c.document
            .toDelta()
            .toJson()
            .where((op) => op['insert'] is Map)
            .single['insert'],
        {'table': table.encode()},
      );
      c.undo();
      expect(c.document.toDelta().toJson(), before);
      c.redo();
      expect(c.document.toPlainText(), '$prefix\n\uFFFC\n后文\n');
      c.dispose();
    }
  });
}
