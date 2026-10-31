import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing.dart';

class DrawingRepository {
  String _key(String pdfPath) => 'pdf_drawings_${pdfPath.hashCode}';

  Future<List<PageDrawing>> getDrawingsForPdf(String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(pdfPath));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PageDrawing.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDrawingsForPdf(
      String pdfPath, List<PageDrawing> drawings) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(drawings.map((d) => d.toJson()).toList());
    await prefs.setString(_key(pdfPath), raw);
  }
}