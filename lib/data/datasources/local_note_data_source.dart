import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/note.dart';

class LocalNoteDataSource {
  static const String _storageKeyPrefix = 'pdf_notes_';

  Future<List<Note>> getNotes(String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storageKeyPrefix${pdfPath.hashCode}';
    final List<String>? rawNotes = prefs.getStringList(key);

    if (rawNotes == null) return [];
    return rawNotes.map((e) => Note.fromJson(e)).toList();
  }

  Future<void> saveNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storageKeyPrefix${note.pdfPath.hashCode}';
    final notes = await getNotes(note.pdfPath);

    notes.removeWhere((n) => n.id == note.id);
    notes.add(note);

    final rawList = notes.map((n) => n.toJson()).toList();
    await prefs.setStringList(key, rawList);
  }

  Future<void> deleteNote(String noteId, String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storageKeyPrefix${pdfPath.hashCode}';
    final notes = await getNotes(pdfPath);

    notes.removeWhere((n) => n.id == noteId);

    final rawList = notes.map((n) => n.toJson()).toList();
    await prefs.setStringList(key, rawList);
  }
}