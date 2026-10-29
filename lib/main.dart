import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/datasources/local_note_data_source.dart';
import 'data/repositories/note_repository_impl.dart';
import 'presentation/viewmodels/pdf_viewer_viewmodel.dart';
import 'presentation/views/main_navigation_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localDataSource = LocalNoteDataSource();
    final noteRepository = NoteRepositoryImpl(localDataSource: localDataSource);

    return ChangeNotifierProvider(
      create: (_) => PdfViewerViewModel(noteRepository: noteRepository),
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<PdfViewerViewModel>().isDarkMode;

    return MaterialApp(
      title: 'Clean MVVM PDF Reader',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 123, 84, 191),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 123, 84, 191),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}