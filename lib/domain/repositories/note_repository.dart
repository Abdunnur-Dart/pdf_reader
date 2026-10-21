import '../models/note.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotesForPdf(String pdfPath);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String noteId, String pdfPath);
}