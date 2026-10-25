import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Keep cursor/focus notifications off the full-document serialization path.
/// Revision is synchronous, so an edit is visible before controller listeners
/// run; listening to the asynchronous changes stream would miss that boundary.
class JournalEditorCache {
  quill.Document? _document;
  int? _revision;
  List<dynamic>? _data;
  List<dynamic>? _snapshotData;
  String? _title;
  bool? _titleBold;
  List<String>? _tags;
  String? _snapshot;

  List<dynamic> documentData(quill.Document document) {
    if (!identical(document, _document) || document.revision != _revision) {
      _document = document;
      _revision = document.revision;
      _data = document.toDelta().toJson();
    }
    return _data!;
  }

  String snapshot({
    required quill.Document document,
    required String title,
    required bool titleBold,
    required List<String> tags,
  }) {
    final data = documentData(document);
    if (_snapshot != null &&
        identical(data, _snapshotData) &&
        title == _title &&
        titleBold == _titleBold &&
        listEquals(tags, _tags)) {
      return _snapshot!;
    }
    _snapshotData = data;
    _title = title;
    _titleBold = titleBold;
    _tags = List<String>.from(tags);
    return _snapshot = jsonEncode({
      'title': title,
      'document': data,
      'tags': tags,
      'titleBold': titleBold,
    });
  }
}
