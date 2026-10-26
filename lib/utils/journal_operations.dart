import 'dart:math';
import 'package:flutter_quill/quill_delta.dart';
import '../models/journal_table.dart';

enum JournalOperation {
  clearBlankLines('清除空行'),
  normalizeSpaces('空格管理'),
  removeLeadingPunctuation('标点管理'),
  removeBold('取消加粗'),
  promoteHeadings('标题升级'),
  demoteHeadings('标题降级'),
  capitalize('首字母大写'),
  shuffleBullets('打乱无序列表'),
  checkAll('勾选全部'),
  uncheckAll('清空勾选'),
  addSentencePeriods('补全句号');

  const JournalOperation(this.label);
  final String label;
}

// Fold the two legacy punctuation chain entries into one operation at the
// first existing position, so saved chains keep their surrounding order.
List<JournalOperation> normalizeJournalOperations(
  Iterable<JournalOperation> operations,
) {
  final result = <JournalOperation>[];
  var punctuationAdded = false;
  for (var operation in operations) {
    if (operation == JournalOperation.addSentencePeriods) {
      operation = JournalOperation.removeLeadingPunctuation;
    }
    if (operation == JournalOperation.removeLeadingPunctuation) {
      if (punctuationAdded) continue;
      punctuationAdded = true;
    }
    result.add(operation);
  }
  return result;
}

class _Atom {
  _Atom(this.value, Map<String, dynamic>? attributes)
    : attributes = Map<String, dynamic>.from(attributes ?? {});
  dynamic value;
  final Map<String, dynamic> attributes;
}

class _Line {
  _Line(this.atoms, this.attributes);
  List<_Atom> atoms;
  final Map<String, dynamic> attributes;
  bool get blank => atoms.every(
    (a) => a.value is String && (a.value as String).trim().isEmpty,
  );
  bool get bullet => attributes['list'] == 'bullet';
  int get indent => attributes['indent'] as int? ?? 0;
}

List<_Line> _lines(List<dynamic> document) {
  final lines = <_Line>[];
  var atoms = <_Atom>[];
  for (final raw in document) {
    final attributes = Map<String, dynamic>.from(
      raw['attributes'] as Map? ?? {},
    );
    final insert = raw['insert'];
    if (insert is! String) {
      atoms.add(_Atom(insert, attributes));
      continue;
    }
    // Work at rune boundaries to retain emoji and supplementary Han characters.
    for (final rune in insert.runes) {
      if (rune == 10) {
        lines.add(_Line(atoms, Map.from(attributes)));
        atoms = [];
      } else {
        atoms.add(_Atom(String.fromCharCode(rune), attributes));
      }
    }
  }
  if (atoms.isNotEmpty) lines.add(_Line(atoms, {}));
  return lines;
}

bool _english(dynamic value) =>
    value is String && RegExp(r'^[A-Za-z0-9]$').hasMatch(value);
bool _han(dynamic value) {
  if (value is! String || value.runes.length != 1) return false;
  final rune = value.runes.single;
  return (rune >= 0x3400 && rune <= 0x9fff) ||
      (rune >= 0x20000 && rune <= 0x323af);
}

bool _space(_Atom atom) =>
    atom.value is String && RegExp(r'^\s$').hasMatch(atom.value);

bool _spacedSymbol(dynamic value) =>
    value is String && RegExp(r'^[+\-×÷/@\\]$').hasMatch(value);

List<_Atom> _normalize(List<_Atom> atoms) {
  // Code spans are opaque except for whitespace at their two boundaries.
  // A span can cross bold/italic delta runs, so group by the code attribute.
  final trimmed = <_Atom>[];
  for (var i = 0; i < atoms.length;) {
    if (atoms[i].attributes['code'] != true) {
      trimmed.add(atoms[i++]);
      continue;
    }
    var end = i + 1;
    while (end < atoms.length && atoms[end].attributes['code'] == true) {
      end++;
    }
    var start = i;
    var last = end;
    while (start < last && _space(atoms[start])) {
      start++;
    }
    while (last > start && _space(atoms[last - 1])) {
      last--;
    }
    trimmed.addAll(atoms.sublist(start, last));
    i = end;
  }
  atoms = trimmed;
  // Trim each logical line before spacing normalization, including Unicode
  // whitespace and leading runs split across different rich-text styles.
  atoms = atoms
      .skipWhile(
        (atom) =>
            atom.value is String && (atom.value as String).trimLeft().isEmpty,
      )
      .toList();
  final out = <_Atom>[];
  for (var i = 0; i < atoms.length; i++) {
    final atom = atoms[i];
    if (atom.attributes['code'] == true) {
      out.add(atom);
      continue;
    }
    if (_space(atom)) {
      var next = i + 1;
      while (next < atoms.length && _space(atoms[next])) {
        next++;
      }
      if (out.isNotEmpty &&
          next < atoms.length &&
          out.last.attributes['code'] != true &&
          atoms[next].attributes['code'] != true) {
        final left = out.last.value;
        final right = atoms[next].value;
        // English punctuation retains ordinary separation ("hello, world").
        final leftEnglish =
            _english(left) ||
            (left is String && RegExp(r"^[,.;:!?\)\]\}'’]$").hasMatch(left));
        final rightEnglish =
            _english(right) ||
            (right is String && RegExp(r"^[\(\[\{'‘]$").hasMatch(right));
        if (_spacedSymbol(left) ||
            _spacedSymbol(right) ||
            (leftEnglish && rightEnglish) ||
            (_han(left) && _english(right)) ||
            (_english(left) && _han(right))) {
          out.add(_Atom(' ', atom.attributes));
        }
      }
      i = next - 1;
      continue;
    }
    if (out.isNotEmpty &&
        out.last.attributes['code'] != true &&
        !_space(out.last) &&
        (_spacedSymbol(out.last.value) ||
            _spacedSymbol(atom.value) ||
            (_han(out.last.value) && _english(atom.value)) ||
            (_english(out.last.value) && _han(atom.value)))) {
      out.add(_Atom(' ', atom.attributes));
    }
    out.add(atom);
  }
  return out;
}

final _punctuation = RegExp(r'^\p{P}$', unicode: true);
final _pairedPunctuation = RegExp(
  r'^[\p{Ps}\p{Pe}\p{Pi}\p{Pf}]$',
  unicode: true,
);

List<_Atom> _removeLeadingPunctuation(List<_Atom> atoms) {
  var leading = true;
  return atoms.where((atom) {
    if (!leading) return true;
    if (atom.attributes['code'] == true) {
      leading = false;
      return true;
    }
    if (_space(atom)) return true;
    final value = atom.value;
    if (value is String &&
        _punctuation.hasMatch(value) &&
        !_pairedPunctuation.hasMatch(value) &&
        !['"', "'", '＂', '＇', '<', '>'].contains(value)) {
      return false;
    }
    // An opening quote/bracket is meaningful content; do not clean inside it.
    leading = false;
    return true;
  }).toList();
}

bool _closingMark(_Atom atom) =>
    RegExp(r'''^[\p{Pe}\p{Pf}"'＂＇」』]$''', unicode: true).hasMatch(atom.value);

bool _sentenceTerminator(dynamic value) =>
    value is String && RegExp(r'^[。.!?！？…]$').hasMatch(value);

bool _sentenceBeforePair(List<_Atom> atoms, int end) {
  const openingFor = {
    '）': '（',
    ')': '(',
    '】': '【',
    ']': '[',
    '}': '{',
    '》': '《',
    '〉': '〈',
    '］': '［',
    '｝': '｛',
    '〕': '〔',
    '〗': '〖',
    '〙': '〘',
    '〛': '〚',
    '｠': '｟',
    '”': '“',
    '’': '‘',
    '」': '「',
    '』': '『',
    '»': '«',
    '›': '‹',
    '"': '"',
    "'": "'",
    '＂': '＂',
    '＇': '＇',
  };
  final closing = atoms[end].value;
  final opening = openingFor[closing];
  if (opening == null) return false;
  var depth = 1;
  for (var i = end - 1; i >= 0; i--) {
    final atom = atoms[i];
    if (atom.attributes['code'] == true) continue;
    if (atom.value == opening) {
      depth--;
      if (depth == 0) {
        var before = i - 1;
        while (before >= 0 &&
            _space(atoms[before]) &&
            atoms[before].attributes['code'] != true) {
          before--;
        }
        return before >= 0 &&
            atoms[before].attributes['code'] != true &&
            _sentenceTerminator(atoms[before].value);
      }
    } else if (atom.value == closing) {
      depth++;
    }
  }
  return false;
}

void _normalizeSentenceEnding(List<_Atom> atoms) {
  var last = atoms.lastIndexWhere((a) => !_space(a));
  if (last < 0) return;
  final first = atoms.firstWhere((a) => !_space(a));
  const quotes = {
    '“': '”',
    '‘': '’',
    '「': '」',
    '『': '』',
    '"': '"',
    "'": "'",
    '＂': '＂',
    '＇': '＇',
  };
  final closing = quotes[first.value];
  if (first.attributes['code'] != true && closing != null) {
    final start = atoms.indexOf(first);
    final hasClosing = atoms
        .skip(start + 1)
        .any((a) => a.value == closing && a.attributes['code'] != true);
    if (!hasClosing) {
      atoms.insert(last + 1, _Atom(closing, first.attributes));
      last++;
    }
  }

  // A trailing aside may follow an already complete sentence. Match its
  // opening mark rather than treating any earlier punctuation as sentence end.
  var enclosed = last;
  while (enclosed >= 0 &&
      ['。', '.'].contains(atoms[enclosed].value) &&
      atoms[enclosed].attributes['code'] != true) {
    enclosed--;
  }
  final closingEnd = enclosed;
  while (enclosed >= 0 &&
      _closingMark(atoms[enclosed]) &&
      atoms[enclosed].attributes['code'] != true) {
    enclosed--;
  }
  final internallyFinished =
      enclosed < closingEnd &&
      enclosed >= 0 &&
      _sentenceTerminator(atoms[enclosed].value) &&
      atoms[enclosed].attributes['code'] != true;
  final afterSentence = [
    for (var end = closingEnd; end > enclosed; end--)
      _sentenceBeforePair(atoms, end),
  ].any((finished) => finished);
  if (internallyFinished || afterSentence) {
    atoms.removeRange(closingEnd + 1, last + 1);
    return;
  }
  final tail = atoms[last];
  if (tail.attributes['code'] == true) {
    // Append outside the span; punctuation must not become part of the code.
    final attributes = Map<String, dynamic>.from(tail.attributes)
      ..remove('code')
      ..remove('link');
    atoms.insert(last + 1, _Atom('。', attributes));
    return;
  }
  if (_closingMark(tail) ||
      !RegExp(r'^[\p{P}\p{S}]$', unicode: true).hasMatch(tail.value)) {
    atoms.insert(last + 1, _Atom('。', tail.attributes));
  }
}

String transformJournalText(String text, JournalOperation operation) {
  if (operation == JournalOperation.removeLeadingPunctuation) {
    return text
        .split('\n')
        .map(
          (line) => _removeLeadingPunctuation(
            line.runes.map((r) => _Atom(String.fromCharCode(r), {})).toList(),
          ).map((atom) => atom.value).join(),
        )
        .join('\n');
  }
  if (operation == JournalOperation.capitalize) {
    return text.replaceAllMapped(
      RegExp(r'\b[a-zA-Z]'),
      (m) =>
          m.start >= 2 &&
              text[m.start - 1] == '.' &&
              RegExp(r'[A-Za-z0-9_]').hasMatch(text[m.start - 2])
          ? m[0]!
          : m[0]!.toUpperCase(),
    );
  }
  if (operation == JournalOperation.normalizeSpaces) {
    return text
        .split('\n')
        .map(
          (line) => _normalize(
            line.runes.map((r) => _Atom(String.fromCharCode(r), {})).toList(),
          ).map((a) => a.value).join(),
        )
        .join('\n');
  }
  if (operation == JournalOperation.clearBlankLines) {
    return text.split('\n').where((line) => line.trim().isNotEmpty).join('\n');
  }
  return text;
}

/// Availability describes the note, not the saved chain. Chain editing always
/// exposes the complete operation set, even when the current note is empty.
Set<JournalOperation> availableJournalOperations(
  List<dynamic> document, {
  String title = '',
  bool titleBold = false,
}) {
  final result = <JournalOperation>{
    JournalOperation.removeLeadingPunctuation,
    JournalOperation.normalizeSpaces,
  };
  if (titleBold) result.add(JournalOperation.removeBold);
  var hasLetters = RegExp(r'[A-Za-z]').hasMatch(title);
  for (final line in _lines(document)) {
    if (line.blank) result.add(JournalOperation.clearBlankLines);
    if (line.bullet) result.add(JournalOperation.shuffleBullets);
    if (line.attributes['header'] != null) {
      result.addAll([
        JournalOperation.promoteHeadings,
        JournalOperation.demoteHeadings,
      ]);
    }
    if (['checked', 'unchecked'].contains(line.attributes['list'])) {
      result.addAll([JournalOperation.checkAll, JournalOperation.uncheckAll]);
    }
    for (final atom in line.atoms) {
      if (atom.attributes['bold'] == true &&
          !line.attributes.containsKey('header')) {
        result.add(JournalOperation.removeBold);
      }
      if (atom.value is String && atom.attributes['code'] != true) {
        hasLetters |= RegExp(r'[A-Za-z]').hasMatch(atom.value as String);
      }
      if (atom.value is Map && atom.value['table'] is String) {
        final table = JournalTableData.decode(atom.value['table']);
        hasLetters |= RegExp(r'[A-Za-z]').hasMatch(table.plainText);
        if (table.headerBold) result.add(JournalOperation.removeBold);
      }
    }
  }
  if (hasLetters) result.add(JournalOperation.capitalize);
  return result;
}

// Shuffle sibling items with their descendants, then shuffle each nested list.
// Separate bullet runs never exchange content, nor do ordered lists.
List<_Line> _shuffle(List<_Line> lines, Random random) {
  if (lines.length < 2) return lines;
  final minimum = lines.map((line) => line.indent).reduce(min);
  final groups = <List<_Line>>[];
  for (final line in lines) {
    if (groups.isEmpty || line.indent == minimum) groups.add([]);
    groups.last.add(line);
  }
  for (final group in groups) {
    if (group.length > 1) {
      final nested = _shuffle(group.sublist(1), random);
      group.replaceRange(1, group.length, nested);
    }
  }
  groups.shuffle(random);
  return groups.expand((group) => group).toList();
}

List<dynamic> transformJournalDocument(
  List<dynamic> document,
  JournalOperation operation, {
  Random? random,
}) {
  var lines = _lines(document);
  if (operation == JournalOperation.clearBlankLines) {
    lines = lines.where((line) => !line.blank).toList();
  }
  for (final line in lines) {
    if ((operation == JournalOperation.checkAll ||
            operation == JournalOperation.uncheckAll) &&
        ['checked', 'unchecked'].contains(line.attributes['list'])) {
      line.attributes['list'] = operation == JournalOperation.checkAll
          ? 'checked'
          : 'unchecked';
    }
    if (operation == JournalOperation.promoteHeadings ||
        operation == JournalOperation.demoteHeadings) {
      final header = line.attributes['header'];
      if (header is int) {
        line.attributes['header'] =
            (header + (operation == JournalOperation.promoteHeadings ? -1 : 1))
                .clamp(1, 3);
      }
    }
    if (operation == JournalOperation.removeBold) {
      line.attributes.remove('bold');
    }
    var inWord = false;
    for (var i = 0; i < line.atoms.length; i++) {
      final atom = line.atoms[i];
      if (operation == JournalOperation.removeBold &&
          !line.attributes.containsKey('header')) {
        atom.attributes['bold'] = false;
      }
      if (operation == JournalOperation.capitalize) {
        final word =
            atom.value is String &&
            RegExp(r'^[A-Za-z0-9_]$').hasMatch(atom.value);
        if (word && !inWord && atom.attributes['code'] != true) {
          atom.value = (atom.value as String).toUpperCase();
        }
        final joinsWord =
            atom.value == '.' &&
            inWord &&
            i + 1 < line.atoms.length &&
            line.atoms[i + 1].value is String &&
            RegExp(r'^[A-Za-z0-9_]$').hasMatch(line.atoms[i + 1].value);
        inWord = word || joinsWord;
      }
      final value = atom.value;
      if (value is Map && value['table'] is String) {
        var table = JournalTableData.decode(value['table']);
        for (final row in table.rows) {
          for (var column = 0; column < table.columns; column++) {
            table = table.edit(
              row.id,
              column,
              transformJournalText(row.cells[column], operation),
            );
          }
        }
        if (operation == JournalOperation.removeBold) {
          table = table.withoutBold();
        }
        atom.value = <String, dynamic>{
          ...Map<String, dynamic>.from(value),
          'table': table.encode(),
        };
      }
    }
    if (operation == JournalOperation.removeLeadingPunctuation &&
        !line.attributes.containsKey('code-block')) {
      line.atoms = _removeLeadingPunctuation(line.atoms);
    }
    if ((operation == JournalOperation.addSentencePeriods ||
            operation == JournalOperation.removeLeadingPunctuation) &&
        !line.blank &&
        line.atoms.every((a) => a.value is String) &&
        !['header', 'code-block'].any(line.attributes.containsKey)) {
      _normalizeSentenceEnding(line.atoms);
    }
    if (operation == JournalOperation.normalizeSpaces &&
        !line.attributes.containsKey('header')) {
      line.atoms = _normalize(line.atoms);
    }
  }
  if (operation == JournalOperation.shuffleBullets) {
    final shuffled = <_Line>[];
    for (var i = 0; i < lines.length;) {
      if (!lines[i].bullet) {
        shuffled.add(lines[i++]);
        continue;
      }
      var end = i + 1;
      while (end < lines.length && lines[end].bullet) {
        end++;
      }
      shuffled.addAll(_shuffle(lines.sublist(i, end), random ?? Random()));
      i = end;
    }
    lines = shuffled;
  }
  final delta = Delta();
  for (final line in lines) {
    for (final atom in line.atoms) {
      delta.insert(
        atom.value,
        atom.attributes.isEmpty ? null : atom.attributes,
      );
    }
    delta.insert('\n', line.attributes.isEmpty ? null : line.attributes);
  }
  if (lines.isEmpty) delta.insert('\n');
  return delta.toJson();
}

/// Export indentation belongs only to ordinary prose, never tables or lists.
List<dynamic> journalImageDocument(List<dynamic> document, bool indent) {
  if (!indent) return document;
  final delta = Delta();
  for (final line in _lines(document)) {
    if (!line.blank &&
        line.atoms.every((a) => a.value is String) &&
        ![
          'header',
          'list',
          'blockquote',
          'code-block',
        ].any(line.attributes.containsKey)) {
      delta.insert('　　');
    }
    for (final atom in line.atoms) {
      delta.insert(
        atom.value,
        atom.attributes.isEmpty ? null : atom.attributes,
      );
    }
    delta.insert('\n', line.attributes.isEmpty ? null : line.attributes);
  }
  return delta.toJson();
}
