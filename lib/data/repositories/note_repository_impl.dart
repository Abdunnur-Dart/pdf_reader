import '../../domain/models/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/local_note_data_source.dart';

class NoteRepositoryImpl implements NoteRepository {
  final LocalNoteDataSource localDataSource;

  NoteRepositoryImpl({required this.localDataSource});

  @override
  Future<List<Note>> getNotesForPdf(String pdfPath) =>
      localDataSource.getNotes(pdfPath); // ← если getNotes() без аргументов, уберите pdfPath

  @override
  Future<void> saveNote(Note note) => localDataSource.saveNote(note);

  @override
  Future<void> deleteNote(String noteId, String pdfPath) =>
      localDataSource.deleteNote(noteId, pdfPath); // ← если deleteNote 1 аргумент, уберите pdfPath
}