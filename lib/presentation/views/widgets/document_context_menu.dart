import 'package:flutter/material.dart';

enum DocumentAction { open, delete }

/// Показывает контекстное меню для документа.
Future<DocumentAction?> showDocumentContextMenu({
  required BuildContext context,
  required String fileName,
  required Offset position,
}) async {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final scheme = Theme.of(context).colorScheme;

  return await showMenu<DocumentAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay!.size.width - position.dx,
      overlay.size.height - position.dy,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    color: scheme.surfaceContainerHighest,
    items: [
      PopupMenuItem<DocumentAction>(
        enabled: false,
        height: 32,
        child: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<DocumentAction>(
        value: DocumentAction.open,
        child: Row(
          children: [
            Icon(Icons.open_in_new_rounded,
                size: 20, color: scheme.onSurface),
            const SizedBox(width: 12),
            const Text('Открыть'),
          ],
        ),
      ),
      PopupMenuItem<DocumentAction>(
        value: DocumentAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                size: 20, color: scheme.error),
            const SizedBox(width: 12),
            Text('Удалить файл', style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
    ],
  );
}