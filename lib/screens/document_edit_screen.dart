import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_document.dart';
import '../models/scan_page.dart';
import '../providers/document_edit_controller.dart';
import '../providers/documents_store.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/filter_selector.dart';
import '../widgets/page_thumbnail.dart';
import 'page_preview_screen.dart';

/// Edits one document: reorder/delete/add pages, choose a filter, export PDF.
class DocumentEditScreen extends StatefulWidget {
  const DocumentEditScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentEditScreen> createState() => _DocumentEditScreenState();
}

class _DocumentEditScreenState extends State<DocumentEditScreen> {
  late final DocumentEditController _controller;
  final ScannerService _scanner = const ScannerService();
  final PdfService _pdf = const PdfService();

  ImageFilterType _selectedFilter = ImageFilterType.blackwhite;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<DocumentsStore>();
    final doc = store.documents.firstWhere(
      (d) => d.id == widget.documentId,
      orElse: () => ScanDocument(
        id: widget.documentId,
        title: 'Scan',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: const [],
      ),
    );
    _controller = DocumentEditController(document: doc, store: store);
    if (doc.pages.isNotEmpty) {
      _selectedFilter = doc.pages.first.filter;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addPages() async {
    final messenger = ScaffoldMessenger.of(context);
    List<String> paths;
    try {
      paths = await _scanner.scanPages();
    } on ScannerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    try {
      await _controller.addPagesFromScan(paths, _selectedFilter);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not add pages: $e')),
        );
      }
    }
  }

  Future<void> _changeFilter(ImageFilterType filter) async {
    final previous = _selectedFilter;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _selectedFilter = filter);
    try {
      await _controller.setFilterAll(filter);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedFilter = previous);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not apply filter: $e')),
      );
    }
  }

  Future<List<Uint8List>> _collectPageImages(ScanDocument doc) async {
    final images = <Uint8List>[];
    for (final page in doc.pages) {
      images.add(await File(page.displayPath).readAsBytes());
    }
    return images;
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final doc = _controller.document;
    if (doc.pages.isEmpty) return;

    // Capture the share-popover anchor (needed on iPad) before any await.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    setState(() => _exporting = true);
    try {
      final images = await _collectPageImages(doc);
      final bytes = await _pdf.buildPdf(images);
      await _pdf.share(
        bytes,
        filename: '${_sanitize(doc.title)}.pdf',
        origin: origin,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _print() async {
    final messenger = ScaffoldMessenger.of(context);
    final doc = _controller.document;
    if (doc.pages.isEmpty) return;

    setState(() => _exporting = true);
    try {
      final images = await _collectPageImages(doc);
      final bytes = await _pdf.buildPdf(images);
      await _pdf.printDoc(bytes, name: doc.title);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return cleaned.isEmpty ? 'scoresnap' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final doc = _controller.document;
        final busy = _controller.isProcessing || _exporting;
        return Scaffold(
          appBar: AppBar(
            title: _EditableTitle(title: doc.title, onChanged: _controller.rename),
            actions: [
              IconButton(
                tooltip: 'Add pages',
                onPressed: busy ? null : _addPages,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
              IconButton(
                tooltip: 'Print',
                onPressed: (busy || doc.pages.isEmpty) ? null : _print,
                icon: const Icon(Icons.print_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: (busy || doc.pages.isEmpty) ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: const Text('Export PDF'),
          ),
          body: BusyOverlay(
            busy: busy,
            message: _exporting ? 'Building PDF…' : 'Processing…',
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilterSelector(
                    value: _selectedFilter,
                    onChanged: busy ? (_) {} : _changeFilter,
                  ),
                ),
                Expanded(
                  child: doc.pages.isEmpty
                      ? const Center(child: Text('No pages in this document.'))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                          itemCount: doc.pages.length,
                          onReorder: _controller.reorderPage,
                          itemBuilder: (context, i) {
                            final page = doc.pages[i];
                            return PageThumbnail(
                              key: ValueKey(page.id),
                              page: page,
                              index: i,
                              processing: _controller.isPageProcessing(page.id),
                              onDelete: () => _controller.deletePage(i),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PagePreviewScreen(page: page),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// AppBar title that opens a rename dialog when tapped.
class _EditableTitle extends StatelessWidget {
  const _EditableTitle({required this.title, required this.onChanged});

  final String title;
  final ValueChanged<String> onChanged;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      onChanged(result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _edit(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          const Icon(Icons.edit_outlined, size: 16),
        ],
      ),
    );
  }
}
