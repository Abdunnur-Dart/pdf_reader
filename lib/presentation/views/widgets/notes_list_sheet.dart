import 'package:flutter/material.dart';
import '../../viewmodels/pdf_viewer_viewmodel.dart';

class NotesListSheet extends StatelessWidget {
  final PdfViewerViewModel viewModel;

  const NotesListSheet({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final notes = viewModel.notes;

    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заметки документа (${notes.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('Заметок пока нет'))
                : ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(note.content),
                          subtitle: Text(
                            'Стр. ${note.pageNumber} • "${note.selectedText}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => viewModel.deleteNote(note.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}