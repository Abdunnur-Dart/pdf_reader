import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pdf_viewer_viewmodel.dart';
import 'pdf_viewer_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека PDF'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Карточка быстрого открытия
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 48, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Открыть документ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Выберите PDF файл на устройстве',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
// В файле library_page.dart при нажатии на открытие книги:
onPressed: () async {
  await viewModel.pickPdfFile();
  if (viewModel.filePath != null && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel, // Передаем текущий инстанс ViewModel в новый маршрут
          child: const PdfViewerPage(),
        ),
      ),
    );
  }
},
                      child: const Text('Выбрать'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Последний документ', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: viewModel.filePath == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Нет открытых документов', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.book, color: Colors.deepPurple),
                            title: Text(viewModel.fileName ?? 'Документ'),
                            subtitle: Text(viewModel.filePath ?? ''),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const PdfViewerPage(),
      ),
    ),
  );
},
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}