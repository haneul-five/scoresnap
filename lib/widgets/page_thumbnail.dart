import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_page.dart';

/// A single reorderable page thumbnail in the document editor.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({
    super.key,
    required this.page,
    required this.index,
    required this.processing,
    required this.onDelete,
    required this.onTap,
  });

  final ScanPage page;
  final int index;
  final bool processing;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Image.file(
                        File(page.displayPath),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    if (processing)
                      const ColoredBox(
                        color: Colors.black45,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Page ${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Delete page',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
