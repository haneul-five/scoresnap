import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_document.dart';
import '../models/scan_page.dart';
import '../services/image_processor.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

/// App-level store owning the saved-document library and its persistence.
///
/// All mutations are user-triggered (never called during build), so calling
/// [notifyListeners] after each one is safe.
class DocumentsStore extends ChangeNotifier {
  DocumentsStore({StorageService? storage, ImageProcessor? processor})
      : _storage = storage ?? StorageService(),
        _processor = processor ?? const ImageProcessor();

  final StorageService _storage;
  final ImageProcessor _processor;

  final List<ScanDocument> _documents = [];
  bool _isLoading = true;

  List<ScanDocument> get documents => List.unmodifiable(_documents);
  bool get isLoading => _isLoading;

  /// Exposed so per-edit controllers can reuse the same storage instance.
  StorageService get storage => _storage;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final loaded = await _storage.loadIndex();
    _documents
      ..clear()
      ..addAll(loaded);
    _isLoading = false;
    notifyListeners();
  }

  /// Imports a single scanner output file as a new page, processes it with
  /// [filter], and returns the resulting page.
  Future<ScanPage> importAndProcess(
    String docId,
    String srcPath,
    ImageFilterType filter,
  ) async {
    final pageId = _uuid.v4();
    final storedSource =
        await _storage.importSourceFile(srcPath, docId, pageId);
    final page = ScanPage(
      id: pageId,
      sourceImagePath: storedSource,
      filter: filter,
    );
    return processPage(docId, page);
  }

  /// Re-processes [page] according to its current filter, saving the processed
  /// bytes, and returns the updated page. For [ImageFilterType.original] the
  /// processed image is cleared and the source is shown directly.
  Future<ScanPage> processPage(String docId, ScanPage page) async {
    final previousProcessed = page.processedImagePath;
    if (page.filter == ImageFilterType.original) {
      if (previousProcessed != null) {
        await _storage.deleteFileAt(previousProcessed);
      }
      return page.copyWith(clearProcessed: true);
    }
    final bytes = await File(page.sourceImagePath).readAsBytes();
    final processed = await _processor.process(bytes, page.filter);
    // Version the filename so the path changes on every re-process; this busts
    // the path-keyed FileImage cache so the new filter result renders.
    final token = _uuid.v4().substring(0, 8);
    final path =
        await _storage.saveProcessedBytes(docId, page.id, token, processed);
    if (previousProcessed != null && previousProcessed != path) {
      await _storage.deleteFileAt(previousProcessed);
    }
    return page.copyWith(processedImagePath: path);
  }

  /// Creates a new document from freshly scanned source paths, processing each
  /// page with the default black & white filter, persists it, and inserts it
  /// at the front of the library.
  Future<ScanDocument> createDocumentFromScan(
    List<String> sourcePaths, {
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final docId = _uuid.v7();
    final pages = <ScanPage>[];
    try {
      for (final src in sourcePaths) {
        pages.add(
          await importAndProcess(docId, src, ImageFilterType.blackwhite),
        );
      }
    } catch (_) {
      // Roll back any files imported before the failure so they do not leak
      // (the document was never added to the index, so nothing else cleans up).
      await _storage.deleteDocumentImages(docId);
      rethrow;
    }
    final doc = ScanDocument(
      id: docId,
      title: _defaultTitle(timestamp),
      createdAt: timestamp,
      updatedAt: timestamp,
      pages: pages,
    );
    _documents.insert(0, doc);
    await _storage.saveIndex(_documents);
    notifyListeners();
    return doc;
  }

  /// Inserts or replaces [document], stamping a fresh [ScanDocument.updatedAt].
  Future<void> upsert(ScanDocument document) async {
    final updated = document.copyWith(updatedAt: DateTime.now());
    final idx = _documents.indexWhere((d) => d.id == document.id);
    if (idx >= 0) {
      _documents[idx] = updated;
    } else {
      _documents.insert(0, updated);
    }
    await _storage.saveIndex(_documents);
    notifyListeners();
  }

  Future<void> deleteDocument(String id) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    final doc = _documents.removeAt(idx);
    await _storage.deleteDocument(doc);
    await _storage.saveIndex(_documents);
    notifyListeners();
  }

  Future<void> renameDocument(String id, String title) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    _documents[idx] =
        _documents[idx].copyWith(title: title, updatedAt: DateTime.now());
    await _storage.saveIndex(_documents);
    notifyListeners();
  }

  String _defaultTitle(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Scan ${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
