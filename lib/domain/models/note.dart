class Note {
  final String id;
  final String pdfPath;
  final int pageNumber;
  final String selectedText;
  final String title; // НОВОЕ ПОЛЕ
  final String content;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.pdfPath,
    required this.pageNumber,
    required this.selectedText,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Note copyWith({
    String? title,
    String? content,
  }) {
    return Note(
      id: id,
      pdfPath: pdfPath,
      pageNumber: pageNumber,
      selectedText: selectedText,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pdfPath': pdfPath,
        'pageNumber': pageNumber,
        'selectedText': selectedText,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        pdfPath: json['pdfPath'] as String,
        pageNumber: json['pageNumber'] as int,
        selectedText: json['selectedText'] as String,
        title: json['title'] as String? ?? 'Без названия', // Поддержка старых заметок
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}