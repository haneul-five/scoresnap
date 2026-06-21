import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/documents_store.dart';
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
  bool _busy = false;

  Future<void> _startScan() async {
    final store = context.read<DocumentsStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    List<String> paths;
    try {
      paths = await _scanner.scanPages();
    } on ScannerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (paths.isEmpty) return;

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
          SnackBar(content: Text('Could not process scan: $e')),
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
      appBar: AppBar(title: const Text('ScoreSnap')),
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
