import 'package:flutter/material.dart';
import '../../viewmodels/pdf_viewer_viewmodel.dart';

class BookmarksSheet extends StatelessWidget {
  final PdfViewerViewModel viewModel;

  const BookmarksSheet({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final bookmarks = viewModel.bookmarks;

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
                'Закладки (${bookmarks.length})',
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
            child: bookmarks.isEmpty
                ? const Center(child: Text('Закладок пока нет'))
                : ListView.builder(
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.bookmark, color: Colors.amber),
                          title: Text(bookmark.title),
                          subtitle: Text('Страница ${bookmark.pageNumber}'),
                          onTap: () {
                            viewModel.goToPage(bookmark.pageNumber);
                            Navigator.pop(context);
                          },
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