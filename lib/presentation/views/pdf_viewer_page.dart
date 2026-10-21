import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final tappedWord = viewModel.tappedWord;
    final existingNote = tappedWord != null ? viewModel.getExistingNote(tappedWord) : null;

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
                      color: viewModel.isCurrentPageBookmarked ? Colors.amber : null,
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
                  const Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey),
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
                PdfViewer.file(
                  viewModel.filePath!,
                  params: PdfViewerParams(
                    maxScale: 5.0,
                    scaleEnabled: true,
                    scaleByPointerScale: 1.15,
                    textSelectionParams: const PdfTextSelectionParams(enabled: true),
                    onViewerReady: (doc, controller) =>
                        viewModel.onDocumentLoaded(doc, controller),
                    onPageChanged: (page) => viewModel.onPageChanged(page),
                    onGeneralTap: (context, controller, details) {
                      viewModel.handleWordSelectionAt(details.localPosition);
                      return true;
                    },
                  ),
                ),
                if (viewModel.isFullScreen)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                        onPressed: viewModel.toggleFullScreen,
                      ),
                    ),
                  ),
                // Карточка с заметкой или словом (теперь отображается и в полноэкранном режиме)
                if (tappedWord != null)
                  Positioned(
                    bottom: 80,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    existingNote != null ? 'Заметка:' : 'Слово:',
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
                                existingNote != null ? Icons.edit : Icons.note_add,
                                size: 18,
                              ),
                              label: Text(
                                existingNote != null ? 'Изменить' : 'Создать',
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
                if (viewModel.totalPages > 0 && !viewModel.isFullScreen)
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
//d