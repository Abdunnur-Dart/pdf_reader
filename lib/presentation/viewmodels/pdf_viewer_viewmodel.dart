import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/bookmark.dart';
import '../../domain/models/note.dart';
import '../../domain/repositories/note_repository.dart';

class PdfViewerViewModel extends ChangeNotifier {
  final NoteRepository noteRepository;

  PdfViewerViewModel({required this.noteRepository}) {
    _initSavedFile();
    _initTheme();
  }

  String? _filePath;
  String? _fileName;
  int _totalPages = 0;
  int _currentPage = 1;
  List<Note> _notes = [];
  List<Bookmark> _bookmarks = [];
  bool _isDarkMode = false;
  bool _isFullScreen = false;

  PdfViewerController? pdfViewerController;

  String? get filePath => _filePath;
  String? get fileName => _fileName;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  List<Note> get notes => _notes;
  List<Bookmark> get bookmarks => _bookmarks;
  bool get isDarkMode => _isDarkMode;
  bool get isFullScreen => _isFullScreen;

  String? tappedWord;
  List<Rect> _selectionRects = [];
  List<Rect> get selectionRects => _selectionRects;

  Future<void> _initSavedFile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('last_pdf_path');
    final savedName = prefs.getString('last_pdf_name');

    if (savedPath != null) {
      _filePath = savedPath;
      _fileName = savedName ?? 'Документ';
      await loadNotes();
      await loadBookmarks();
      notifyListeners();
    }
  }

  Future<void> _initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  void toggleFullScreen() {
    _isFullScreen = !_isFullScreen;
    notifyListeners();
  }

  Future<void> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _filePath = result.files.single.path;
      _fileName = result.files.single.name;
      _currentPage = 1;
      tappedWord = null;
      _selectionRects = [];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_pdf_path', _filePath!);
      await prefs.setString('last_pdf_name', _fileName!);

      await loadNotes();
      await loadBookmarks();
      notifyListeners();
    }
  }

  void onDocumentLoaded(PdfDocument document, PdfViewerController controller) {
    _totalPages = document.pages.length;
    pdfViewerController = controller;
    notifyListeners();
  }

  void onPageChanged(int? pageNumber) {
    if (pageNumber != null) {
      _currentPage = pageNumber;
      notifyListeners();
    }
  }

  void clearSelection() {
    if (tappedWord != null || _selectionRects.isNotEmpty) {
      tappedWord = null;
      _selectionRects = [];

      final delegate = pdfViewerController?.textSelectionDelegate;
      if (delegate != null) {
        try {
          (delegate as dynamic).clearSelection();
        } catch (_) {}
      }

      notifyListeners();
    }
  }

  void setSelectedWord(String? word) {
    if (tappedWord != word) {
      tappedWord = word;
      notifyListeners();
    }
  }

  Note? getExistingNote(String word) {
    try {
      return _notes.firstWhere(
        (n) =>
            n.pageNumber == _currentPage &&
            n.selectedText.trim().toLowerCase() == word.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> loadNotes() async {
    if (_filePath == null) return;
    _notes = await noteRepository.getNotesForPdf(_filePath!);
    notifyListeners();
  }

  Future<void> saveOrUpdateNote(String content, {String? existingNoteId}) async {
    if (_filePath == null || tappedWord == null) return;

    final note = Note(
      id: existingNoteId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      pdfPath: _filePath!,
      pageNumber: _currentPage,
      selectedText: tappedWord!,
      content: content,
      createdAt: DateTime.now(),
    );

    await noteRepository.saveNote(note);
    clearSelection();
    await loadNotes();
  }

  Future<void> deleteNote(String noteId) async {
    if (_filePath == null) return;
    await noteRepository.deleteNote(noteId, _filePath!);
    await loadNotes();
  }

  bool get isCurrentPageBookmarked {
    if (_filePath == null) return false;
    return _bookmarks.any((b) => b.pageNumber == _currentPage);
  }

  Future<void> loadBookmarks() async {
    if (_filePath == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'pdf_bookmarks_${_filePath.hashCode}';
    final List<String>? rawList = prefs.getStringList(key);

    if (rawList != null) {
      _bookmarks = rawList.map((e) => Bookmark.fromJson(e)).toList();
    } else {
      _bookmarks = [];
    }
    notifyListeners();
  }

  Future<void> toggleBookmark() async {
    if (_filePath == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'pdf_bookmarks_${_filePath.hashCode}';

    if (isCurrentPageBookmarked) {
      _bookmarks.removeWhere((b) => b.pageNumber == _currentPage);
    } else {
      final newBookmark = Bookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pdfPath: _filePath!,
        pageNumber: _currentPage,
        title: 'Страница $_currentPage',
        createdAt: DateTime.now(),
      );
      _bookmarks.add(newBookmark);
    }

    final rawList = _bookmarks.map((b) => b.toJson()).toList();
    await prefs.setStringList(key, rawList);
    notifyListeners();
  }

  void goToPage(int pageNumber) {
    if (pdfViewerController != null && pageNumber >= 1 && pageNumber <= _totalPages) {
      pdfViewerController!.goToPage(pageNumber: pageNumber);
    }
  }

  Future<void> handleWordSelectionAt(Offset localPosition) async {
    if (pdfViewerController == null) return;
    try {
      final delegate = pdfViewerController!.textSelectionDelegate;
      await delegate.selectWord(localPosition);
      final selected = await delegate.getSelectedText();

      _selectionRects = [];
      try {
        final dynamicDelegate = delegate as dynamic;
        final selectionState = dynamicDelegate.selectionState ?? dynamicDelegate.value;

        if (selectionState != null) {
          final rects = selectionState.rects ?? selectionState.selectionRects ?? const [];
          if (rects is List) {
            _selectionRects = rects.whereType<Rect>().toList();
          }
        }
      } catch (_) {}

      if (selected.trim().isNotEmpty) {
        final cleanWord = selected.trim().split(RegExp(r'\s+')).first;
        setSelectedWord(cleanWord);
      } else {
        clearSelection();
      }
    } catch (_) {
      clearSelection();
    }
  }
}