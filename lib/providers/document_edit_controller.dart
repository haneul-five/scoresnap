import 'package:flutter/foundation.dart';

import '../models/scan_document.dart';
import '../models/scan_page.dart';
import 'documents_store.dart';

/// Per-edit-session controller holding a working copy of one [ScanDocument].
/// Mutations re-process affected pages (delegating to [DocumentsStore]) and
/// persist via [DocumentsStore.upsert].
class DocumentEditController extends ChangeNotifier {
  DocumentEditController({
    required ScanDocument document,
    required DocumentsStore store,
  })  : _document = document,
        _store = store;

  final DocumentsStore _store;
  ScanDocument _document;

  bool _isProcessing = false;
  final Set<String> _pagesProcessing = {};

  ScanDocument get document => _document;

  /// True while a whole-document operation (add pages / apply filter to all)
  /// is running.
  bool get isProcessing => _isProcessing;

  /// True while the single page [pageId] is being re-processed.
  bool isPageProcessing(String pageId) => _pagesProcessing.contains(pageId);

  void rename(String title) {
    _document = _document.copyWith(title: title);
    notifyListeners();
    _persist();
  }

  void reorderPage(int oldIndex, int newIndex) {
    final pages = [..._document.pages];
    if (newIndex > oldIndex) newIndex -= 1;
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    _document = _document.copyWith(pages: pages, clearExportedPdf: true);
    notifyListeners();
    _persist();
  }

  Future<void> deletePage(int index) async {
    final pages = [..._document.pages];
    final removed = pages.removeAt(index);
    _document = _document.copyWith(pages: pages, clearExportedPdf: true);
    notifyListeners();
    await _store.storage.deletePageFiles(removed);
    await _persist();
  }

  Future<void> addPagesFromScan(
    List<String> sourcePaths,
    ImageFilterType filter,
  ) async {
    if (sourcePaths.isEmpty) return;
    _isProcessing = true;
    notifyListeners();
    final newPages = <ScanPage>[];
    try {
      for (final src in sourcePaths) {
        newPages.add(
          await _store.importAndProcess(_document.id, src, filter),
        );
      }
      _document = _document.copyWith(
        pages: [..._document.pages, ...newPages],
        clearExportedPdf: true,
      );
    } catch (_) {
      // Clean up files for any pages imported before the failure.
      for (final page in newPages) {
        await _store.storage.deletePageFiles(page);
      }
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
    await _persist();
  }

  Future<void> setFilterForPage(int index, ImageFilterType filter) async {
    final page = _document.pages[index];
    if (page.filter == filter) return;
    _pagesProcessing.add(page.id);
    notifyListeners();
    try {
      final updated = await _store.processPage(
        _document.id,
        page.copyWith(filter: filter),
      );
      final pages = [..._document.pages];
      pages[index] = updated;
      _document = _document.copyWith(pages: pages, clearExportedPdf: true);
    } finally {
      _pagesProcessing.remove(page.id);
      notifyListeners();
    }
    await _persist();
  }

  Future<void> setFilterAll(ImageFilterType filter) async {
    if (_document.pages.isEmpty) return;
    _isProcessing = true;
    notifyListeners();
    try {
      final pages = <ScanPage>[];
      for (final page in _document.pages) {
        pages.add(
          await _store.processPage(_document.id, page.copyWith(filter: filter)),
        );
      }
      _document = _document.copyWith(pages: pages, clearExportedPdf: true);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
    await _persist();
  }

  Future<void> _persist() => _store.upsert(_document);
}
