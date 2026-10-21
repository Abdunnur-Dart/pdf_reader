import '../../domain/models/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/local_note_data_source.dart';

class NoteRepositoryImpl implements NoteRepository {
  final LocalNoteDataSource dataSource;

  NoteRepositoryImpl({required this.dataSource});

  @override
  Future<List<Note>> getNotesForPdf(String pdfPath) async {
    return await dataSource.getNotes(pdfPath);
  }

  @override
  Future<void> saveNote(Note note) async {
    await dataSource.saveNote(note);
  }

  @override
  Future<void> deleteNote(String noteId, String pdfPath) async {
    await dataSource.deleteNote(noteId, pdfPath);
  }
}