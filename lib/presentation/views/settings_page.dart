import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pdf_viewer_viewmodel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Темная тема'),
            subtitle: const Text('Включить темный режим интерфейса'),
            value: viewModel.isDarkMode,
            onChanged: (value) {
              viewModel.toggleTheme(value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            subtitle: const Text('Clean MVVM PDF Reader v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'PDF Читалка с заметками',
                applicationVersion: '1.0.0',
                applicationLegalese: 'AbdTeam',
              );
            },
          ),
        ],
      ),
    );
  }
}