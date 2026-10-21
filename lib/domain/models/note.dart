import 'dart:convert';

class Note {
  final String id;
  final String pdfPath;
  final int pageNumber;
  final String selectedText;
  final String content;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.pdfPath,
    required this.pageNumber,
    required this.selectedText,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfPath': pdfPath,
      'pageNumber': pageNumber,
      'selectedText': selectedText,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      pdfPath: map['pdfPath'] as String,
      pageNumber: map['pageNumber'] as int,
      selectedText: map['selectedText'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory Note.fromJson(String source) =>
      Note.fromMap(json.decode(source) as Map<String, dynamic>);
}