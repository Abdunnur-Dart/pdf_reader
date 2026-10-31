import 'dart:ui';

class DrawingStroke {
  final List<Offset> points; // нормализованные 0..1 относительно страницы
  final Color color;
  final double width;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => [p.dx, p.dy]).toList(),
        'color': color.toARGB32(),
        'width': width,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    return DrawingStroke(
      points: pts,
      color: Color(json['color'] as int),
      width: (json['width'] as num).toDouble(),
    );
  }
}

class PageDrawing {
  final int pageNumber;
  final List<DrawingStroke> strokes;

  PageDrawing({required this.pageNumber, required this.strokes});

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory PageDrawing.fromJson(Map<String, dynamic> json) => PageDrawing(
        pageNumber: json['pageNumber'] as int,
        strokes: (json['strokes'] as List)
            .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}