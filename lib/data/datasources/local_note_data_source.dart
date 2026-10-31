import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/note.dart';

class LocalNoteDataSource {
  String _key(String pdfPath) => 'pdf_notes_${pdfPath.hashCode}';

  Future<List<Note>> getNotes(String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(pdfPath));
    if (raw == null) return [];
    return raw
        .map((e) => Note.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(note.pdfPath);
    final existing = prefs.getStringList(key) ?? [];

    final updated = existing
        .map((e) => Note.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .where((n) => n.id != note.id)
        .toList()
      ..add(note);

    await prefs.setStringList(
        key, updated.map((n) => jsonEncode(n.toJson())).toList());
  }

  Future<void> deleteNote(String noteId, String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(pdfPath);
    final existing = prefs.getStringList(key) ?? [];

    final updated = existing
        .map((e) => Note.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .where((n) => n.id != noteId)
        .toList();

    await prefs.setStringList(
        key, updated.map((n) => jsonEncode(n.toJson())).toList());
  }
}