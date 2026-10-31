import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../domain/models/drawing.dart';
import '../../domain/models/note.dart';
import '../viewmodels/pdf_viewer_viewmodel.dart';
import 'widgets/bookmarks_sheet.dart';
import 'widgets/note_dialog.dart';
import 'widgets/notes_list_sheet.dart';

class PdfViewerPage extends StatelessWidget {
  const PdfViewerPage({super.key});

  void _showNoteDialog(
    BuildContext context,
    PdfViewerViewModel viewModel,
    String word,
    Note? existingNote,
  ) {
    showDialog(
      context: context,
      builder: (_) => NoteDialog(
        selectedText: word,
        initialContent: existingNote?.content ?? '',
        isEditing: existingNote != null,
        onSave: (content) => viewModel.saveOrUpdateNote(
          content,
          existingNoteId: existingNote?.id,
        ),
      ),
    );
  }

  void _showNotesSheet(BuildContext context, PdfViewerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NotesListSheet(viewModel: viewModel),
    );
  }

  void _showBookmarksSheet(BuildContext context, PdfViewerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BookmarksSheet(viewModel: viewModel),
    );
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke, Rect pageRect) {
    if (stroke.points.length < 2) return;
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = stroke.points.first;
    path.moveTo(
      pageRect.left + first.dx * pageRect.width,
      pageRect.top + first.dy * pageRect.height,
    );
    for (var i = 1; i < stroke.points.length; i++) {
      final p = stroke.points[i];
      path.lineTo(
        pageRect.left + p.dx * pageRect.width,
        pageRect.top + p.dy * pageRect.height,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final tappedWord = viewModel.tappedWord;
    final existingNote =
        tappedWord != null ? viewModel.getExistingNote(tappedWord) : null;

    return Scaffold(
      appBar: viewModel.isFullScreen
          ? null
          : AppBar(
              title: Text(viewModel.fileName ?? 'PDF Читалка'),
              actions: [
                if (viewModel.filePath != null) ...[
                  IconButton(
                    icon: Icon(
                      viewModel.isCurrentPageBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: viewModel.isCurrentPageBookmarked
                          ? Colors.amber
                          : null,
                    ),
                    tooltip: 'Закладка',
                    onPressed: viewModel.toggleBookmark,
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmarks_outlined),
                    tooltip: 'Все закладки',
                    onPressed: () => _showBookmarksSheet(context, viewModel),
                  ),
                  IconButton(
                    icon: const Icon(Icons.list_alt),
                    tooltip: 'Все заметки',
                    onPressed: () => _showNotesSheet(context, viewModel),
                  ),
                  IconButton(
                    icon: Icon(
                      viewModel.isDrawMode ? Icons.edit : Icons.edit_outlined,
                    ),
                    color: viewModel.isDrawMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    tooltip: 'Рисование',
                    onPressed: viewModel.toggleDrawMode,
                  ),
                  if (viewModel.isDrawMode) ...[
                    IconButton(
                      icon: Icon(
                        viewModel.isEraserMode
                            ? Icons.auto_fix_high
                            : Icons.auto_fix_normal,
                      ),
                      color: viewModel.isEraserMode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      tooltip: 'Ластик',
                      onPressed: viewModel.toggleEraser,
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo),
                      tooltip: 'Отменить штрих',
                      onPressed: viewModel.undoLastStroke,
                    ),
                  ],
                ],
                IconButton(
                  icon: Icon(
                    viewModel.isFullScreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                  ),
                  tooltip: 'Полноэкранный режим',
                  onPressed: viewModel.toggleFullScreen,
                ),
              ],
            ),
      body: viewModel.filePath == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: viewModel.pickPdfFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Выбрать PDF файл'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // ─────────────────────────────────────────────
                // 1) PDF + сохранённые штрихи + подсветки
                // ─────────────────────────────────────────────
                PdfViewer.file(
                  viewModel.filePath!,
                  params: PdfViewerParams(
                    sizeDelegateProvider:
                        const PdfViewerSizeDelegateProviderLegacy(
                      maxScale: 5.0,
                    ),
                    scaleEnabled: true,
                    scaleByPointerScale: 1.15,
                    textSelectionParams: const PdfTextSelectionParams(
                      enabled: false,
                    ),
                    pagePaintCallbacks: [
                      (canvas, pageRect, page) {
                        // 1.1 сохранённые штрихи
                        final strokes = viewModel.currentPageStrokes;
                        for (final stroke in strokes) {
                          _drawStroke(canvas, stroke, pageRect);
                        }

                        // 1.2 зелёное выделение слова
                        final selectedRects = viewModel.selectedWordPdfRects;
                        if (selectedRects.isNotEmpty) {
                          final selectedPaint = Paint()
                            ..color = Colors.green.withValues(alpha: 0.35)
                            ..style = PaintingStyle.fill;
                          for (final pdfRect in selectedRects) {
                            final rect = pdfRect.toRectInDocument(
                              page: page,
                              pageRect: pageRect,
                            );
                            canvas.drawRRect(
                              RRect.fromRectAndRadius(
                                rect,
                                const Radius.circular(3),
                              ),
                              selectedPaint,
                            );
                          }
                        }

                        // 1.3 жёлтые заметки
                        final notedRects =
                            viewModel.notedWordPdfRectsExcludingSelection;
                        if (notedRects.isNotEmpty) {
                          final paint = Paint()
                            ..color = Colors.yellow.withValues(alpha: 0.4)
                            ..style = PaintingStyle.fill;
                          for (final pdfRect in notedRects) {
                            final rect = pdfRect.toRectInDocument(
                              page: page,
                              pageRect: pageRect,
                            );
                            canvas.drawRRect(
                              RRect.fromRectAndRadius(
                                rect,
                                const Radius.circular(3),
                              ),
                              paint,
                            );
                          }
                        }
                      },
                    ],
                    onViewerReady: (doc, controller) =>
                        viewModel.onDocumentLoaded(doc, controller),
                    onPageChanged: (page) => viewModel.onPageChanged(page),
                    onGeneralTap: (context, controller, details) {
                      if (viewModel.isDrawMode) return false;
                      viewModel.handleWordSelectionAt(details.localPosition);
                      return true;
                    },
                  ),
                ),

                // ─────────────────────────────────────────────
                // 2) Слой живого рисования / ластика
                // ─────────────────────────────────────────────
                if (viewModel.isDrawMode)
                  _DrawingOverlay(viewModel: viewModel),

                // ─────────────────────────────────────────────
                // 3) Кнопка выхода из полноэкранного режима
                // ─────────────────────────────────────────────
                if (viewModel.isFullScreen)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit,
                            color: Colors.white),
                        onPressed: viewModel.toggleFullScreen,
                      ),
                    ),
                  ),

                // ─────────────────────────────────────────────
                // 4) Карточка выделенного слова / заметки
                // ─────────────────────────────────────────────
                if (tappedWord != null)
                  Positioned(
                    bottom: 80,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    existingNote != null
                                        ? 'Заметка:'
                                        : 'Слово:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    existingNote != null
                                        ? existingNote.content
                                        : '"$tappedWord"',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: Icon(
                                existingNote != null
                                    ? Icons.visibility
                                    : Icons.note_add,
                                size: 18,
                              ),
                              label: Text(
                                existingNote != null
                                    ? 'Просмотреть'
                                    : 'Добавить',
                              ),
                              onPressed: () {
                                _showNoteDialog(
                                  context,
                                  viewModel,
                                  tappedWord,
                                  existingNote,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Закрыть',
                              onPressed: viewModel.clearSelection,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ─────────────────────────────────────────────
                // 5) ПАНЕЛЬ ИНСТРУМЕНТОВ РИСОВАНИЯ / ЛАСТИКА
                // ─────────────────────────────────────────────
                if (viewModel.isDrawMode)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 8,
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: viewModel.isEraserMode
                            // --- Режим ластика ---
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.auto_fix_high, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Режим ластика: водите пальцем по штрихам',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              )
                            // --- Режим рисования ---
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      for (final c in const [
                                        Colors.red,
                                        Colors.blue,
                                        Colors.green,
                                        Colors.orange,
                                        Colors.purple,
                                        Colors.black,
                                      ])
                                        GestureDetector(
                                          onTap: () =>
                                              viewModel.setDrawColor(c),
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: viewModel.drawColor == c
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.transparent,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.line_weight, size: 18),
                                      Expanded(
                                        child: Slider(
                                          min: 1,
                                          max: 12,
                                          value: viewModel.drawWidth,
                                          label: viewModel.drawWidth
                                              .toStringAsFixed(0),
                                          onChanged: viewModel.setDrawWidth,
                                        ),
                                      ),
                                      Text(
                                        viewModel.drawWidth
                                            .toStringAsFixed(0),
                                        style:
                                            const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                // ─────────────────────────────────────────────
                // 6) Счётчик страниц
                // ─────────────────────────────────────────────
                if (viewModel.totalPages > 0 &&
                    !viewModel.isFullScreen &&
                    !viewModel.isDrawMode)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Страница ${viewModel.currentPage} из ${viewModel.totalPages}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// Слой живого рисования / ластика
// ═════════════════════════════════════════════════════════
class _DrawingOverlay extends StatefulWidget {
  final PdfViewerViewModel viewModel;
  const _DrawingOverlay({required this.viewModel});

  @override
  State<_DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<_DrawingOverlay> {
  bool _active = false;

  Offset? _toNormalized(Offset local) {
    final controller = widget.viewModel.pdfViewerController;
    if (controller == null) return null;
    try {
      final pageIndex = widget.viewModel.currentPage - 1;
      final layouts = controller.layout.pageLayouts;
      if (pageIndex < 0 || pageIndex >= layouts.length) return null;

      final pageRect = layouts[pageIndex];
      final docPos = controller.localToDocument(local);
      if (!pageRect.contains(docPos)) return null;

      final dx = (docPos.dx - pageRect.left) / pageRect.width;
      final dy = (docPos.dy - pageRect.top) / pageRect.height;
      if (dx < 0 || dx > 1 || dy < 0 || dy > 1) return null;
      return Offset(dx, dy);
    } catch (_) {
      return null;
    }
  }

  void _handleStart(Offset local) {
    final p = _toNormalized(local);
    if (p == null) return;
    if (widget.viewModel.isEraserMode) {
      widget.viewModel.eraseAt(p);
    } else {
      _active = true;
      widget.viewModel.startStroke(p);
    }
  }

  void _handleUpdate(Offset local) {
    final p = _toNormalized(local);
    if (p == null) return;
    if (widget.viewModel.isEraserMode) {
      widget.viewModel.eraseAt(p);
    } else if (_active) {
      widget.viewModel.appendPoint(p);
    }
  }

  void _handleEnd() {
    if (_active) {
      _active = false;
      widget.viewModel.endStroke();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _handleStart(d.localPosition),
        onPanUpdate: (d) => _handleUpdate(d.localPosition),
        onPanEnd: (_) => _handleEnd(),
        onPanCancel: _handleEnd,
        onTapDown: widget.viewModel.isEraserMode
            ? (d) => _handleStart(d.localPosition)
            : null,
        child: CustomPaint(
          painter: _LiveStrokePainter(widget.viewModel),
          size: Size.infinite,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// Рисует незавершённый штрих в экранных координатах
// ═════════════════════════════════════════════════════════
class _LiveStrokePainter extends CustomPainter {
  final PdfViewerViewModel vm;
  _LiveStrokePainter(this.vm) : super(repaint: vm);

  @override
  void paint(Canvas canvas, Size size) {
    final s = vm.currentStroke;
    if (s == null || s.points.length < 2) return;

    final controller = vm.pdfViewerController;
    if (controller == null) return;

    final pageIndex = vm.currentPage - 1;
    final layouts = controller.layout.pageLayouts;
    if (pageIndex < 0 || pageIndex >= layouts.length) return;

    final pageRect = layouts[pageIndex];

    Offset docToLocal(Offset docPoint) {
      try {
        return controller.documentToLocal(docPoint);
      } catch (_) {
        return docPoint;
      }
    }

    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = s.points.first;
    var docPoint = Offset(
      pageRect.left + first.dx * pageRect.width,
      pageRect.top + first.dy * pageRect.height,
    );
    var local = docToLocal(docPoint);
    path.moveTo(local.dx, local.dy);

    for (var i = 1; i < s.points.length; i++) {
      final p = s.points[i];
      docPoint = Offset(
        pageRect.left + p.dx * pageRect.width,
        pageRect.top + p.dy * pageRect.height,
      );
      local = docToLocal(docPoint);
      path.lineTo(local.dx, local.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiveStrokePainter oldDelegate) => true;
}