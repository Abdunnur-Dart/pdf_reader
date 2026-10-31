import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/bookmark.dart';
import '../../domain/models/drawing.dart';
import '../../domain/models/note.dart';
import '../../domain/repositories/drawing_repository.dart';
import '../../domain/repositories/note_repository.dart';

class PdfViewerViewModel extends ChangeNotifier {
  final NoteRepository noteRepository;
  final DrawingRepository drawingRepository;

  PdfViewerViewModel({
    required this.noteRepository,
    required this.drawingRepository,
  }) {
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

  final List<String> _documents = [];

  PdfViewerController? pdfViewerController;

  final Map<int, PdfPageText> _pageTextCache = {};
  final Map<int, List<PdfRect>> _notedWordPdfRectsCache = {};
  final Map<int, List<PdfRect>> _selectedWordPdfRectsCache = {};

  // === РИСОВАНИЕ ===
  bool _isDrawMode = false;
  Color _drawColor = Colors.red;
  double _drawWidth = 3.0;
  final List<PageDrawing> _drawings = [];
  DrawingStroke? _currentStroke;

  // === ЛАСТИК ===
  bool _isEraserMode = false;

  String? get filePath => _filePath;
  String? get fileName => _fileName;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  List<Note> get notes => _notes;
  List<Bookmark> get bookmarks => _bookmarks;
  bool get isDarkMode => _isDarkMode;
  bool get isFullScreen => _isFullScreen;

  List<String> get documents => List.unmodifiable(_documents);

  String? tappedWord;

  List<PdfRect> get notedWordPdfRects =>
      _notedWordPdfRectsCache[_currentPage] ?? const [];
  List<PdfRect> get selectedWordPdfRects =>
      _selectedWordPdfRectsCache[_currentPage] ?? const [];

  List<PdfRect> get notedWordPdfRectsExcludingSelection {
    final noted = notedWordPdfRects;
    final selected = selectedWordPdfRects;
    if (noted.isEmpty) return const [];
    if (selected.isEmpty) return noted;
    return noted.where((notedRect) {
      for (final selRect in selected) {
        if (_pdfRectsIntersect(notedRect, selRect)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  // === Геттеры рисования / ластика ===
  bool get isDrawMode => _isDrawMode;
  bool get isEraserMode => _isEraserMode;
  Color get drawColor => _drawColor;
  double get drawWidth => _drawWidth;
  DrawingStroke? get currentStroke => _currentStroke;
  List<PageDrawing> get drawings => List.unmodifiable(_drawings);

  /// Штрихи текущей страницы (для pagePaintCallbacks).
  List<DrawingStroke> get currentPageStrokes {
    for (final d in _drawings) {
      if (d.pageNumber == _currentPage) return d.strokes;
    }
    return const [];
  }

  static bool _pdfRectsIntersect(PdfRect a, PdfRect b) {
    const epsilon = 1.0;
    return a.left < b.right - epsilon &&
        a.right > b.left + epsilon &&
        a.top < b.bottom - epsilon &&
        a.bottom > b.top + epsilon;
  }

  static List<PdfRect> _mergeCharRectsToLines(List<PdfRect> charRects) {
    if (charRects.isEmpty) return const [];
    if (charRects.length == 1) {
      final r = charRects.first;
      return [PdfRect(r.left - 2.0, r.top - 2.0, r.right + 2.0, r.bottom + 2.0)];
    }

    final sorted = List<PdfRect>.from(charRects)
      ..sort((a, b) => a.top.compareTo(b.top));
    final lines = <List<PdfRect>>[];

    for (final rect in sorted) {
      final centerY = (rect.top + rect.bottom) / 2;
      List<PdfRect>? currentLine;

      for (final line in lines) {
        final lineTop =
            line.map((r) => r.top).reduce((a, b) => a < b ? a : b);
        final lineBottom =
            line.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);

        if (centerY >= lineTop && centerY <= lineBottom) {
          currentLine = line;
          break;
        }
      }

      if (currentLine == null) {
        lines.add([rect]);
      } else {
        currentLine.add(rect);
      }
    }

    final finalRects = <PdfRect>[];
    for (final line in lines) {
      double minLeft = double.infinity;
      double minTop = double.infinity;
      double maxRight = double.negativeInfinity;
      double maxBottom = double.negativeInfinity;

      for (final rect in line) {
        if (rect.left < minLeft) minLeft = rect.left;
        if (rect.top < minTop) minTop = rect.top;
        if (rect.right > maxRight) maxRight = rect.right;
        if (rect.bottom > maxBottom) maxBottom = rect.bottom;
      }

      const padX = 2.0;
      const padY = 2.0;

      finalRects.add(PdfRect(
          minLeft - padX, minTop - padY, maxRight + padX, maxBottom + padY));
    }

    return finalRects;
  }

  Future<void> _initSavedFile() async {
    final prefs = await SharedPreferences.getInstance();

    _documents.clear();
    final docsList = prefs.getStringList('saved_pdf_documents');
    if (docsList != null) {
      _documents.addAll(docsList);
    }

    final savedPath = prefs.getString('last_pdf_path');
    final savedName = prefs.getString('last_pdf_name');

    if (savedPath != null) {
      _filePath = savedPath;
      _fileName = savedName ?? 'Документ';

      if (!_documents.contains(savedPath)) {
        _documents.add(savedPath);
      }

      await loadNotes();
      await loadBookmarks();
      await loadDrawings();
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
      final originalFile = File(result.files.single.path!);
      final originalName = result.files.single.name;

      final appDir = await getApplicationDocumentsDirectory();
      final safeFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final savedFile = File('${appDir.path}/$safeFileName');

      await originalFile.copy(savedFile.path);

      _filePath = savedFile.path;
      _fileName = originalName;
      _currentPage = 1;
      tappedWord = null;
      _currentStroke = null;
      _isDrawMode = false;
      _isEraserMode = false;
      _pageTextCache.clear();
      _notedWordPdfRectsCache.clear();
      _selectedWordPdfRectsCache.clear();
      _drawings.clear();

      if (!_documents.contains(_filePath)) {
        _documents.insert(0, _filePath!);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_pdf_path', _filePath!);
      await prefs.setString('last_pdf_name', _fileName!);
      await prefs.setStringList('saved_pdf_documents', _documents);

      await loadNotes();
      await loadBookmarks();
      await loadDrawings();
      notifyListeners();
    }
  }

  Future<void> removeDocument(String path) async {
    _documents.remove(path);

    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}

    if (_filePath == path) {
      _filePath = null;
      _fileName = null;
      _totalPages = 0;
      _currentPage = 1;
      _notes.clear();
      _bookmarks.clear();
      _drawings.clear();
      _currentStroke = null;
      _isDrawMode = false;
      _isEraserMode = false;
      tappedWord = null;
      _pageTextCache.clear();
      _notedWordPdfRectsCache.clear();
      _selectedWordPdfRectsCache.clear();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_pdf_documents', _documents);

    if (_filePath == null) {
      await prefs.remove('last_pdf_path');
      await prefs.remove('last_pdf_name');
    }

    notifyListeners();
  }

  Future<void> openDocument(String path) async {
    if (_filePath == path) {
      notifyListeners();
      return;
    }

    _filePath = path;
    _fileName = path.split(RegExp(r'[/\\]')).last.split('_').last;
    _currentPage = 1;
    tappedWord = null;
    _currentStroke = null;
    _isDrawMode = false;
    _isEraserMode = false;
    _pageTextCache.clear();
    _notedWordPdfRectsCache.clear();
    _selectedWordPdfRectsCache.clear();
    _drawings.clear();

    _documents.remove(path);
    _documents.insert(0, path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_pdf_path', _filePath!);
    await prefs.setString('last_pdf_name', _fileName!);
    await prefs.setStringList('saved_pdf_documents', _documents);

    await loadNotes();
    await loadBookmarks();
    await loadDrawings();
    notifyListeners();
  }

  void onDocumentLoaded(PdfDocument document, PdfViewerController controller) {
    _totalPages = document.pages.length;
    pdfViewerController = controller;
    _pageTextCache.clear();
    _notedWordPdfRectsCache.clear();
    _selectedWordPdfRectsCache.clear();
    _rebuildNotedWordRects(_currentPage);
    _rebuildSelectedWordRects(_currentPage);
    notifyListeners();
  }

  void onPageChanged(int? pageNumber) {
    if (pageNumber != null) {
      _currentPage = pageNumber;
      _rebuildNotedWordRects(_currentPage);
      _rebuildSelectedWordRects(_currentPage);
      notifyListeners();
    }
  }

  void clearSelection() {
    if (tappedWord != null) {
      tappedWord = null;
      _selectedWordPdfRectsCache[_currentPage] = const [];

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
      _rebuildSelectedWordRects(_currentPage);
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
    _rebuildSelectedWordRects(_currentPage);
    notifyListeners();
  }

  Future<void> saveOrUpdateNote(
    String content, {
    String? existingNoteId,
    String? title,
  }) async {
    if (_filePath == null || tappedWord == null) return;

    String finalTitle = title ?? 'Заметка к "$tappedWord"';

    final note = Note(
      id: existingNoteId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      pdfPath: _filePath!,
      pageNumber: _currentPage,
      selectedText: tappedWord!,
      title: finalTitle,
      content: content,
      createdAt: DateTime.now(),
    );

    await noteRepository.saveNote(note);
    clearSelection();
    await loadNotes();
  }

  Future<void> updateNoteTitle(String noteId, String newTitle) async {
    if (_filePath == null) return;
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final updatedNote = _notes[index].copyWith(title: newTitle);
      await noteRepository.saveNote(updatedNote);
      await loadNotes();
    }
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
    if (pdfViewerController != null &&
        pageNumber >= 1 &&
        pageNumber <= _totalPages) {
      pdfViewerController!.goToPage(pageNumber: pageNumber);
    }
  }

  Future<PdfPageText?> _getPageText(int pageNumber) async {
    final controller = pdfViewerController;
    if (controller == null) return null;
    final pageIndex = pageNumber - 1;
    if (pageIndex < 0 || pageIndex >= controller.document.pages.length) {
      return null;
    }

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

    final rawRects = <PdfRect>[];
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
            rawRects.add(pageText.charRects[i]);
          }
        }
        searchFrom = idx + targetWord.length;
      }
    }

    _notedWordPdfRectsCache[pageNumber] = _mergeCharRectsToLines(rawRects);
    notifyListeners();
  }

  Future<void> _rebuildSelectedWordRects(int pageNumber) async {
    if (_filePath == null) {
      _selectedWordPdfRectsCache[pageNumber] = const [];
      return;
    }

    final word = tappedWord?.trim();
    if (word == null || word.isEmpty) {
      _selectedWordPdfRectsCache[pageNumber] = const [];
      return;
    }

    final pageText = await _getPageText(pageNumber);
    if (pageText == null || pageText.fullText.isEmpty) {
      _selectedWordPdfRectsCache[pageNumber] = const [];
      return;
    }

    final targetWord = word.toLowerCase();
    final separatorPattern = RegExp(r'[\s\p{P}]', unicode: true);
    final rawRects = <PdfRect>[];

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
          rawRects.add(pageText.charRects[i]);
        }
      }
      searchFrom = idx + targetWord.length;
    }

    _selectedWordPdfRectsCache[pageNumber] = _mergeCharRectsToLines(rawRects);
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

      while (startIndex > 0 &&
          !separatorPattern.hasMatch(fullText[startIndex - 1])) {
        startIndex--;
      }
      while (endIndex < fullText.length - 1 &&
          !separatorPattern.hasMatch(fullText[endIndex + 1])) {
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

  // ===================== РИСОВАНИЕ =====================

  Future<void> loadDrawings() async {
    if (_filePath == null) return;
    _drawings
      ..clear()
      ..addAll(await drawingRepository.getDrawingsForPdf(_filePath!));
    notifyListeners();
  }

  void toggleDrawMode() {
    _isDrawMode = !_isDrawMode;
    if (_isDrawMode) {
      clearSelection();
      _isEraserMode = false;
    } else {
      _currentStroke = null;
      _isEraserMode = false;
    }
    notifyListeners();
  }

  void setDrawColor(Color c) {
    _drawColor = c;
    notifyListeners();
  }

  void setDrawWidth(double w) {
    _drawWidth = w;
    notifyListeners();
  }

  /// Старт штриха. Точка в нормализованных координатах страницы (0..1).
  void startStroke(Offset normalizedPoint) {
    _currentStroke = DrawingStroke(
      points: [normalizedPoint],
      color: _drawColor,
      width: _drawWidth,
    );
    notifyListeners();
  }

  void appendPoint(Offset normalizedPoint) {
    final s = _currentStroke;
    if (s == null) return;
    s.points.add(normalizedPoint);
    notifyListeners();
  }

  Future<void> endStroke() async {
    final s = _currentStroke;
    if (s == null || s.points.length < 2) {
      _currentStroke = null;
      notifyListeners();
      return;
    }

    final page = _currentPage;
    final existing = _drawings.where((d) => d.pageNumber == page).toList();
    if (existing.isEmpty) {
      _drawings.add(PageDrawing(pageNumber: page, strokes: [s]));
    } else {
      existing.first.strokes.add(s);
    }

    _currentStroke = null;

    if (_filePath != null) {
      await drawingRepository.saveDrawingsForPdf(_filePath!, _drawings);
    }
    notifyListeners();
  }

  Future<void> undoLastStroke() async {
    final pageList =
        _drawings.where((d) => d.pageNumber == _currentPage).toList();
    if (pageList.isEmpty || pageList.first.strokes.isEmpty) return;
    pageList.first.strokes.removeLast();
    if (_filePath != null) {
      await drawingRepository.saveDrawingsForPdf(_filePath!, _drawings);
    }
    notifyListeners();
  }

  // ===================== ЛАСТИК =====================

  void toggleEraser() {
    _isEraserMode = !_isEraserMode;
    if (_isEraserMode) {
      _currentStroke = null;
    }
    notifyListeners();
  }

  /// Удаляет штрихи текущей страницы, попавшие в радиус ластика.
  /// [normalizedPoint] — координаты 0..1 относительно страницы.
  /// [radius] — радиус ластика в нормализованных координатах.
  Future<bool> eraseAt(Offset normalizedPoint, {double radius = 0.02}) async {
    final pageList =
        _drawings.where((d) => d.pageNumber == _currentPage).toList();
    if (pageList.isEmpty) return false;

    final strokes = pageList.first.strokes;
    final before = strokes.length;

    // Соотношение сторон страницы — чтобы ластик был «круглым»
    final controller = pdfViewerController;
    double aspect = 1.0;
    if (controller != null) {
      final pageIndex = _currentPage - 1;
      final layouts = controller.layout.pageLayouts;
      if (pageIndex >= 0 && pageIndex < layouts.length) {
        final w = layouts[pageIndex].width;
        final h = layouts[pageIndex].height;
        if (h > 0) aspect = w / h;
      }
    }

    bool hitsStroke(DrawingStroke s) {
      double minX = 1, minY = 1, maxX = 0, maxY = 0;
      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      final rx = radius / (aspect > 0 ? aspect : 1.0);
      final ry = radius;
      if (normalizedPoint.dx < minX - rx ||
          normalizedPoint.dx > maxX + rx ||
          normalizedPoint.dy < minY - ry ||
          normalizedPoint.dy > maxY + ry) {
        return false;
      }

      for (final p in s.points) {
        final dx = (p.dx - normalizedPoint.dx) * aspect;
        final dy = p.dy - normalizedPoint.dy;
        if (dx * dx + dy * dy <= radius * radius) return true;
      }
      return false;
    }

    strokes.removeWhere(hitsStroke);

    if (strokes.length == before) return false;

    if (_filePath != null) {
      await drawingRepository.saveDrawingsForPdf(_filePath!, _drawings);
    }
    notifyListeners();
    return true;
  }
}