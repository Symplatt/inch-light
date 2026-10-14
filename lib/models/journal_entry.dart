import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'journal_table.dart';

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.title,
    required List<dynamic> document,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.collectionId,
    this.isPinned = false,
    this.titleBold = false,
    this.isBottom = false,
  }) : document = document.map((op) {
         final attributes = op['attributes'];
         if (attributes is Map &&
             ['checked', 'unchecked'].contains(attributes['list'])) {
           // Keep older notes readable after removing interactive checklists.
           return {
             ...op as Map,
             'attributes': {...attributes, 'list': 'bullet'},
           };
         }
         return op;
       }).toList();

  final String id;
  final String title;
  final List<dynamic> document;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? collectionId;
  final bool isPinned;
  final bool titleBold;
  final bool isBottom;

  JournalEntry copyWith({
    bool? isPinned,
    bool? isBottom,
    String? collectionId,
    bool move = false,
  }) => JournalEntry(
    id: id,
    title: title,
    document: document,
    createdAt: createdAt,
    updatedAt: updatedAt,
    tags: tags,
    collectionId: move ? collectionId : this.collectionId,
    isPinned: isBottom == true ? false : (isPinned ?? this.isPinned),
    isBottom: isPinned == true ? false : (isBottom ?? this.isBottom),
    titleBold: titleBold,
  );

  static List<String> parseTags(String input) => input
      .split(RegExp(r'\s+'))
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  String get content => document
      .map((op) {
        final insert = op['insert'];
        if (insert is String) return insert;
        if (insert is Map && insert['table'] is String) {
          return JournalTableData.decode(insert['table']).plainText;
        }
        return '';
      })
      .join()
      .replaceFirst(RegExp(r'\n$'), '');

  // Count visible characters, including punctuation and whole emoji, not
  // whitespace or formatting objects. The title is deliberately excluded.
  int get wordCount => content.replaceAll(RegExp(r'\s'), '').characters.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'document': document,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
    'collectionId': collectionId,
    'isPinned': isPinned,
    'titleBold': titleBold,
    'isBottom': isBottom,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['createdAt'] as String);
    final raw = json['document'];
    final List<dynamic> delta;
    if (raw == null) {
      // Retain the original record text when upgrading pre-2.0.1 data.
      final text = json['content'] as String;
      delta = [
        {'insert': text.endsWith('\n') ? text : '$text\n'},
      ];
    } else {
      delta = List<dynamic>.from(raw as List);
      if (delta.isEmpty ||
          delta.any((op) => op is! Map || !_validInsert(op['insert'])) ||
          delta.last['insert'] is! String ||
          !(delta.last['insert'] as String).endsWith('\n')) {
        throw const FormatException('Invalid record document');
      }
    }
    final validated = Document.fromJson(delta);
    final normalized = validated.toDelta().toJson();
    validated.close();
    return JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      document: normalized,
      createdAt: created,
      updatedAt: json['updatedAt'] == null
          ? created
          : DateTime.parse(json['updatedAt'] as String),
      tags: parseTags(((json['tags'] as List?) ?? []).cast<String>().join(' ')),
      collectionId: json['collectionId'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      titleBold: json['titleBold'] as bool? ?? false,
      isBottom: json['isBottom'] == true && json['isPinned'] != true,
    );
  }
  static bool _validInsert(dynamic insert) {
    if (insert is String) return true;
    if (insert is! Map || insert.length != 1) return false;
    if (insert['divider'] == 'hr') return true;
    if (insert['table'] is String) {
      JournalTableData.decode(insert['table']);
      return true;
    }
    return false;
  }
}

class JournalCollection {
  const JournalCollection({
    required this.id,
    required this.title,
    this.updatedAt,
  });
  final String id;
  final String title;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory JournalCollection.fromJson(Map<String, dynamic> json) =>
      JournalCollection(
        id: json['id'] as String,
        title: json['title'] as String,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );
}
