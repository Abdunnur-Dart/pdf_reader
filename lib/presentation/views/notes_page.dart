import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pdf_viewer_viewmodel.dart';
import '../../domain/models/note.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final notes = viewModel.notes;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Поиск теперь учитывает и заголовок
    final filteredNotes = notes.where((note) {
      final query = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.selectedText.toLowerCase().contains(query);
    }).toList();

    final Map<String, List<Note>> groupedNotes = {};
    for (var note in filteredNotes) {
      groupedNotes.putIfAbsent(note.pdfPath, () => []).add(note);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Поиск по заметкам...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: notes.isEmpty
                  ? const _EmptyNotesState()
                  : _searchQuery.isNotEmpty
                      ? _buildSearchResults(context, viewModel, filteredNotes)
                      : _buildBooksList(context, groupedNotes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooksList(BuildContext context, Map<String, List<Note>> groupedNotes) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: groupedNotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = groupedNotes.entries.elementAt(index);
        final fileName = entry.key.split(RegExp(r'[/\\]')).last;

        return _BookCard(
          title: fileName,
          notesCount: entry.value.length,
          onTap: () {
            final vm = context.read<PdfViewerViewModel>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: _BookNotesPage(pdfPath: entry.key, bookTitle: fileName),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context, PdfViewerViewModel viewModel, List<Note> filteredNotes) {
    if (filteredNotes.isEmpty) {
      return const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: filteredNotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        final fileName = note.pdfPath.split(RegExp(r'[/\\]')).last;

        return _NoteCard(
          note: note,
          bookName: fileName,
          onDelete: () => viewModel.deleteNote(note.id),
          onEditTitle: () => _showEditTitleDialog(context, viewModel, note),
        );
      },
    );
  }

  // Диалог редактирования названия
  void _showEditTitleDialog(BuildContext context, PdfViewerViewModel viewModel, Note note) {
    final controller = TextEditingController(text: note.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Переименовать заметку'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Новое название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                viewModel.updateNoteTitle(note.id, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _BookNotesPage extends StatefulWidget {
  final String pdfPath;
  final String bookTitle;

  const _BookNotesPage({required this.pdfPath, required this.bookTitle});

  @override
  State<_BookNotesPage> createState() => _BookNotesPageState();
}

class _BookNotesPageState extends State<_BookNotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final currentBookNotes = viewModel.notes.where((n) => n.pdfPath == widget.pdfPath).toList();
    final filteredBookNotes = currentBookNotes.where((note) {
      final query = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.selectedText.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.bookTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('${currentBookNotes.length} заметок', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (currentBookNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Поиск по заметкам книги...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: filteredBookNotes.isEmpty
                  ? const Center(child: Text('Заметок не найдено'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filteredBookNotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final note = filteredBookNotes[index];
                        return _NoteCard(
                          note: note,
                          onDelete: () => viewModel.deleteNote(note.id),
                          onEditTitle: () => _showEditTitleDialog(context, viewModel, note),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context, PdfViewerViewModel viewModel, Note note) {
    final controller = TextEditingController(text: note.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Переименовать заметку'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Новое название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                viewModel.updateNoteTitle(note.id, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final int notesCount;
  final VoidCallback onTap;

  const _BookCard({required this.title, required this.notesCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.menu_book_rounded, color: scheme.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('$notesCount заметок', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final String? bookName;
  final VoidCallback onDelete;
  final VoidCallback onEditTitle;

  const _NoteCard({
    required this.note,
    this.bookName,
    required this.onDelete,
    required this.onEditTitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bookName != null) ...[
            Row(
              children: [
                Icon(Icons.book_outlined, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(bookName!, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title, // Отображаем название
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              // Кнопка редактирования названия
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.edit_outlined, color: scheme.primary, size: 20),
                onPressed: onEditTitle,
              ),
              const SizedBox(width: 8),
              // Кнопка удаления
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: scheme.primary, width: 3)),
            ),
            child: Text('"${note.selectedText}"', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 10),
          Text(note.content, style: TextStyle(color: scheme.onSurface, height: 1.5)),
          const SizedBox(height: 12),
          Text('Стр. ${note.pageNumber}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Заметок пока нет.\nОткройте PDF и добавьте заметку.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
    );
  }
}