import '../../domain/models/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/local_note_data_source.dart';

class NoteRepositoryImpl implements NoteRepository {
  final LocalNoteDataSource localDataSource;

  NoteRepositoryImpl({required this.localDataSource});

  @override
  Future<void> saveNote(Note note) async {
    // В старой версии вы, скорее всего, передавали сюда что-то вроде (note, pdfPath).
    // Теперь LocalNoteDataSource.saveNote принимает только сам объект Note.
    await localDataSource.saveNote(note);
  }

  @override
  Future<void> deleteNote(String noteId, String pdfPath) async {
    // В LocalNoteDataSource.deleteNote мы ищем по ID, pdfPath больше не нужен,
    // так как все заметки хранятся в одном общем списке.
    await localDataSource.deleteNote(noteId);
  }

  @override
  Future<List<Note>> getNotesForPdf(String pdfPath) async {
    // Получаем ВСЕ заметки из базы и фильтруем их по пути к PDF
    final allNotes = await localDataSource.getNotes();
    return allNotes.where((note) => note.pdfPath == pdfPath).toList();
  }
}