import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pdf_viewer_viewmodel.dart';
import 'widgets/document_context_menu.dart'; // Путь к меню
import 'pdf_viewer_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  Future<void> _pickAndOpen(BuildContext context, PdfViewerViewModel vm) async {
    await vm.pickPdfFile();
    if (vm.filePath != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: const PdfViewerPage(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PdfViewerViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final documents = _resolveDocuments(viewModel);
    final hasDocuments = documents.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека'),
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        actions: [
          if (hasDocuments)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton.filledTonal(
                tooltip: 'Открыть PDF',
                onPressed: () => _pickAndOpen(context, viewModel),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = width < 600;
            final isMedium = width >= 600 && width < 900;
            final crossAxisCount = isCompact ? 1 : (isMedium ? 2 : 3);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (!hasDocuments)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 16 : 24,
                        isCompact ? 8 : 16,
                        isCompact ? 16 : 24,
                        0,
                      ),
                      child: _OpenDocumentCard(
                        compact: isCompact,
                        onPick: () => _pickAndOpen(context, viewModel),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 24,
                      hasDocuments ? (isCompact ? 8 : 16) : 28,
                      isCompact ? 16 : 24,
                      8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          hasDocuments ? 'Документы' : 'Последний документ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (hasDocuments) ...[
                          const SizedBox(width: 8),
                          _CountBadge(count: documents.length),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!hasDocuments)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyLibraryState(),
                  )
                else
                  _buildDocumentsSliver(
                    context: context,
                    documents: documents,
                    viewModel: viewModel,
                    crossAxisCount: crossAxisCount,
                    isCompact: isCompact,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _resolveDocuments(PdfViewerViewModel vm) {
    // Если у вас есть список documents в ViewModel — используйте его:
    // return vm.documents; 
    return vm.filePath != null ? [vm.filePath!] : const [];
  }

  Widget _buildDocumentsSliver({
    required BuildContext context,
    required List<String> documents,
    required PdfViewerViewModel viewModel,
    required int crossAxisCount,
    required bool isCompact,
  }) {
    final horizontal = isCompact ? 16.0 : 24.0;

    Widget buildTile(String path) {
      return _RecentDocumentTile(
        fileName: _fileNameOf(viewModel, path),
        filePath: path,
        onTap: () => _openDocument(context, viewModel),
        onContextMenu: (offset) => _showContextMenu(
          context: context,
          viewModel: viewModel,
          path: path,
          offset: offset,
        ),
      );
    }

    if (crossAxisCount == 1) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
        // Исправление ошибки unnecessary_underscores (Dart 3.7+)
        sliver: SliverList.separated(
          itemCount: documents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12), 
          itemBuilder: (context, index) => buildTile(documents[index]),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 92,
        ),
        itemCount: documents.length,
        itemBuilder: (context, index) => buildTile(documents[index]),
      ),
    );
  }

  String _fileNameOf(PdfViewerViewModel vm, String path) {
    if (vm.filePath == path && vm.fileName != null) return vm.fileName!;
    final segments = path.split(RegExp(r'[/\\]'));
    return segments.isEmpty ? path : segments.last;
  }

  void _openDocument(BuildContext context, PdfViewerViewModel vm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: const PdfViewerPage(),
        ),
      ),
    );
  }

  Future<void> _showContextMenu({
    required BuildContext context,
    required PdfViewerViewModel viewModel,
    required String path,
    required Offset offset,
  }) async {
    final fileName = _fileNameOf(viewModel, path);
    final action = await showDocumentContextMenu(
      context: context,
      fileName: fileName,
      position: offset,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case DocumentAction.open:
        _openDocument(context, viewModel);
        break;
      case DocumentAction.delete:
        final confirmed = await _confirmDelete(context, fileName);
        if (confirmed == true && context.mounted) {
          _deleteFile(path, viewModel, context);
        }
        break;
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String fileName) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Удалить файл?'),
        content: Text(
          'Файл «$fileName» будет удалён из библиотеки.\nДействие нельзя отменить.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _deleteFile(
      String path, PdfViewerViewModel viewModel, BuildContext context) {
    
    // Вызываем метод из ViewModel (см. шаг 3)
    viewModel.removeDocument(path);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Файл удалён: ${path.split(RegExp(r'[/\\]')).last}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _OpenDocumentCard extends StatelessWidget {
  final VoidCallback onPick;
  final bool compact;
  const _OpenDocumentCard({required this.onPick, required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.6)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: compact ? 28 : 32,
                  color: scheme.onPrimary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                color: scheme.onPrimary.withOpacity(0.7),
              ),
            ],
          ),
          SizedBox(height: compact ? 18 : 24),
          Text(
            'Открыть документ',
            style:
                (compact ? textTheme.titleLarge : textTheme.headlineSmall)
                    ?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Выберите PDF-файл на устройстве, чтобы начать чтение и делать заметки.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          SizedBox(height: compact ? 16 : 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPick,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                foregroundColor: scheme.primary,
                padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text(
                'Выбрать PDF',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDocumentTile extends StatefulWidget {
  final String fileName;
  final String filePath;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onContextMenu;

  const _RecentDocumentTile({
    required this.fileName,
    required this.filePath,
    required this.onTap,
    this.onContextMenu,
  });

  @override
  State<_RecentDocumentTile> createState() => _RecentDocumentTileState();
}

class _RecentDocumentTileState extends State<_RecentDocumentTile> {
  Offset? _pressPosition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _pressPosition = details.globalPosition;
      },
      onSecondaryTap: () {
        if (_pressPosition != null) {
          widget.onContextMenu?.call(_pressPosition!);
        }
      },
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        widget.onContextMenu?.call(details.globalPosition);
      },
      child: Material(
        color: scheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.filePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Пока пусто',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Открытые документы появятся здесь',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
} 