import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/documents_store.dart';
import '../services/gallery_service.dart';
import '../services/scanner_service.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/document_tile.dart';
import '../widgets/empty_state.dart';
import 'document_edit_screen.dart';

/// Library screen: lists saved documents and starts new scans.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScannerService _scanner = const ScannerService();
  final GalleryService _gallery = const GalleryService();
  bool _busy = false;

  Future<void> _startScan() async {
    final messenger = ScaffoldMessenger.of(context);
    List<String> paths;
    try {
      paths = await _scanner.scanPages();
    } on ScannerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    await _createDocument(paths);
  }

  Future<void> _importFromGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    List<String> paths;
    try {
      paths = await _gallery.pickAndCropImages();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import from gallery: $e')),
      );
      return;
    }
    if (!mounted) return;
    await _createDocument(paths);
  }

  /// Shared flow for both scan and gallery import: build a document from the
  /// given source image paths, process them, then open the editor.
  Future<void> _createDocument(List<String> paths) async {
    if (paths.isEmpty) return;
    final store = context.read<DocumentsStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final doc = await store.createDocumentFromScan(paths);
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => DocumentEditScreen(documentId: doc.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not process images: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DocumentsStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScoreSnap'),
        actions: [
          IconButton(
            tooltip: 'Import from gallery',
            onPressed: _busy ? null : _importFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _startScan,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan'),
      ),
      body: BusyOverlay(
        busy: _busy,
        message: 'Processing scan…',
        child: _buildBody(store),
      ),
    );
  }

  Widget _buildBody(DocumentsStore store) {
    if (store.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final documents = store.documents;
    if (documents.isEmpty) {
      return const EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: documents.length,
      itemBuilder: (context, i) {
        final doc = documents[i];
        return DocumentTile(
          document: doc,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DocumentEditScreen(documentId: doc.id),
            ),
          ),
          onDelete: () => store.deleteDocument(doc.id),
          onRename: (title) => store.renameDocument(doc.id, title),
        );
      },
    );
  }
}
