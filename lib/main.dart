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
    final noteRepository = NoteRepositoryImpl(dataSource: localDataSource);

    return MaterialApp(
      title: 'Clean MVVM PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 123, 84, 191)),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (_) => PdfViewerViewModel(noteRepository: noteRepository),
        child: const MainNavigationPage(),
      ),
    );
  }
}