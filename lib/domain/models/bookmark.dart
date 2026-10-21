import 'dart:convert';

class Bookmark {
  final String id;
  final String pdfPath;
  final int pageNumber;
  final String title;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.pdfPath,
    required this.pageNumber,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfPath': pdfPath,
      'pageNumber': pageNumber,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      pdfPath: map['pdfPath'] as String,
      pageNumber: map['pageNumber'] as int,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory Bookmark.fromJson(String source) =>
      Bookmark.fromMap(json.decode(source) as Map<String, dynamic>);
}