import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pdf_viewer_viewmodel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsSection(
            title: 'Оформление',
            children: [
              _SettingsTile(
                leading: Icons.dark_mode_rounded,
                title: 'Тёмная тема',
                subtitle: 'Тёмный режим интерфейса',
                trailing: Switch(
                  value: viewModel.isDarkMode,
                  onChanged: viewModel.toggleTheme,
                ),
                onTap: () => viewModel.toggleTheme(!viewModel.isDarkMode),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: 'Информация',
            children: [
              _SettingsTile(
                leading: Icons.info_outline_rounded,
                title: 'О приложении',
                subtitle: 'PDF Читалка с заметками v1.1.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'PDF Читалка',
                    applicationVersion: '1.1.0',
                    applicationIcon: const Icon(Icons.auto_stories, size: 48),
                    applicationLegalese: '© AbdTeam',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // ОБЕРНУТО В Material С type: MaterialType.transparency
    // Это решает ошибку "ink splashes may be invisible"
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(leading, color: scheme.onPrimaryContainer, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}