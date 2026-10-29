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

  // NEW: кэш структурированного текста
  final Map<int, PdfPageText> _pageTextCache = {};

  // NEW: кэш прямоугольников слов с заметками (координаты страницы PdfRect)
  final Map<int, List<PdfRect>> _notedWordPdfRectsCache = {};

  String? get filePath => _filePath;
  String? get fileName => _fileName;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  List<Note> get notes => _notes;
  List<Bookmark> get bookmarks => _bookmarks;
  bool get isDarkMode => _isDarkMode;
  bool get isFullScreen => _isFullScreen;

  String? tappedWord;

  // NEW: возвращает PdfRect для текущей страницы, pagePaintCallbacks преобразует их
  List<PdfRect> get notedWordPdfRects {
    return _notedWordPdfRectsCache[_currentPage] ?? const [];
  }

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
      _pageTextCache.clear();
      _notedWordPdfRectsCache.clear();

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
    _pageTextCache.clear();
    _notedWordPdfRectsCache.clear();
    _rebuildNotedWordRects(_currentPage);
    notifyListeners();
  }

  void onPageChanged(int? pageNumber) {
    if (pageNumber != null) {
      _currentPage = pageNumber;
      _rebuildNotedWordRects(_currentPage);
      notifyListeners();
    }
  }

  void clearSelection() {
    if (tappedWord != null) {
      tappedWord = null;

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
    _notedWordPdfRectsCache.clear();
    _rebuildNotedWordRects(_currentPage);
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

  Future<PdfPageText?> _getPageText(int pageNumber) async {
    final controller = pdfViewerController;
    if (controller == null) return null;
    final pageIndex = pageNumber - 1;
    if (pageIndex < 0 || pageIndex >= controller.document.pages.length) return null;

    final cached = _pageTextCache[pageNumber];
    if (cached != null) return cached;

    final page = controller.document.pages[pageIndex];
    try {
      final text = await page.loadStructuredText();
      _pageTextCache[pageNumber] = text;
      return text;
    } catch (_) {
      return null;
    }
  }

  // NEW: пересчитать PdfRect слов с заметками
  Future<void> _rebuildNotedWordRects(int pageNumber) async {
    if (_filePath == null) return;

    final pageNotes = _notes.where((n) => n.pageNumber == pageNumber).toList();
    if (pageNotes.isEmpty) {
      _notedWordPdfRectsCache[pageNumber] = const [];
      return;
    }

    final pageText = await _getPageText(pageNumber);
    if (pageText == null || pageText.fullText.isEmpty) {
      _notedWordPdfRectsCache[pageNumber] = const [];
      return;
    }

    final rects = <PdfRect>[];
    final separatorPattern = RegExp(r'[\s\p{P}]', unicode: true);

    for (final note in pageNotes) {
      final targetWord = note.selectedText.trim().toLowerCase();
      if (targetWord.isEmpty) continue;

      final textLower = pageText.fullText.toLowerCase();
      int searchFrom = 0;
      while (true) {
        final idx = textLower.indexOf(targetWord, searchFrom);
        if (idx < 0) break;

        final beforeOk = idx == 0 ||
            separatorPattern.hasMatch(pageText.fullText[idx - 1]);
        final afterIdx = idx + targetWord.length;
        final afterOk = afterIdx >= pageText.fullText.length ||
            separatorPattern.hasMatch(pageText.fullText[afterIdx]);

        if (beforeOk && afterOk) {
          for (int i = idx; i < afterIdx; i++) {
            if (i >= pageText.charRects.length) break;
            rects.add(pageText.charRects[i]);
          }
        }
        searchFrom = idx + targetWord.length;
      }
    }

    _notedWordPdfRectsCache[pageNumber] = rects;
    notifyListeners();
  }

  Future<void> handleWordSelectionAt(Offset localPosition) async {
    final controller = pdfViewerController;
    if (controller == null) return;

    try {
      final pageIndex = _currentPage - 1;
      if (pageIndex < 0 || pageIndex >= controller.document.pages.length) {
        clearSelection();
        return;
      }

      final page = controller.document.pages[pageIndex];
      final pageText = await _getPageText(_currentPage);
      if (pageText == null) {
        clearSelection();
        return;
      }

      if (pageText.fullText.isEmpty || pageText.charRects.isEmpty) {
        clearSelection();
        return;
      }

      final docPos = controller.localToDocument(localPosition);

      final pageLayouts = controller.layout.pageLayouts;
      if (pageIndex >= pageLayouts.length) {
        clearSelection();
        return;
      }

      final pageRect = pageLayouts[pageIndex];
      if (!pageRect.contains(docPos)) {
        clearSelection();
        return;
      }

      final pageOffset = docPos - pageRect.topLeft;
      final pdfPoint = pageOffset.toPdfPoint(
        page: page,
        scaledPageSize: pageRect.size,
      );

      int hitIndex = -1;
      double minDistance = double.infinity;

      for (int i = 0; i < pageText.charRects.length; i++) {
        final charRect = pageText.charRects[i];
        final charCenter = PdfPoint(
          (charRect.left + charRect.right) / 2,
          (charRect.top + charRect.bottom) / 2,
        );
        final dx = charCenter.x - pdfPoint.x;
        final dy = charCenter.y - pdfPoint.y;
        final distance = dx * dx + dy * dy;
        if (distance < minDistance) {
          minDistance = distance;
          hitIndex = i;
        }
      }

      if (hitIndex < 0) {
        clearSelection();
        return;
      }

      final fullText = pageText.fullText;
      if (hitIndex >= fullText.length) {
        clearSelection();
        return;
      }

      final separatorPattern = RegExp(r'[\s\p{P}]', unicode: true);
      int startIndex = hitIndex;
      int endIndex = hitIndex;

      while (startIndex > 0 && !separatorPattern.hasMatch(fullText[startIndex - 1])) {
        startIndex--;
      }
      while (endIndex < fullText.length - 1 && !separatorPattern.hasMatch(fullText[endIndex + 1])) {
        endIndex++;
      }

      final word = fullText.substring(startIndex, endIndex + 1).trim();
      if (word.isEmpty) {
        clearSelection();
        return;
      }

      setSelectedWord(word);
    } catch (_) {
      clearSelection();
    }
  }
}