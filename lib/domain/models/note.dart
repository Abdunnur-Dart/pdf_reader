class Note {
  final String id;
  final String pdfPath;
  final int pageNumber;
  final String selectedText;
  final String title;
  final String content;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.pdfPath,
    required this.pageNumber,
    required this.selectedText,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Note copyWith({
    String? id,
    String? pdfPath,
    int? pageNumber,
    String? selectedText,
    String? title,
    String? content,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      pdfPath: pdfPath ?? this.pdfPath,
      pageNumber: pageNumber ?? this.pageNumber,
      selectedText: selectedText ?? this.selectedText,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
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
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}