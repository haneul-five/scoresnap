import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/scan_document.dart';
import '../models/scan_page.dart';

/// Owns the on-device storage layout under the app documents directory:
///
/// ```
/// scoresnap/
///   index.json                         (the library; paths stored RELATIVE)
///   images/<docId>/<pageId>_src.<ext>  (source images)
///   images/<docId>/<pageId>_proc.png   (processed images)
///   pdfs/<docId>.pdf                   (last exported PDF)
/// ```
///
/// Image/PDF paths are persisted RELATIVE to the scoresnap root and resolved to
/// absolute paths on load, because the iOS app-container path can change
/// between launches (e.g. after an app update or a restore-from-backup), which
/// would otherwise invalidate stored absolute paths.
class StorageService {
  Directory? _rootCache;

  Future<Directory> _root() async {
    final cached = _rootCache;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/scoresnap');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _rootCache = root;
    return root;
  }

  Future<Directory> _imagesDir(String docId) async {
    final root = await _root();
    final dir = Directory('${root.path}/images/$docId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _pdfsDir() async {
    final root = await _root();
    final dir = Directory('${root.path}/pdfs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ---- path (de)relativization -----------------------------------------

  String _relativize(String absolutePath, String rootPath) {
    final prefix = '$rootPath/';
    return absolutePath.startsWith(prefix)
        ? absolutePath.substring(prefix.length)
        : absolutePath;
  }

  String _absolutize(String storedPath, String rootPath) {
    if (storedPath.startsWith('/')) return storedPath; // already absolute
    return '$rootPath/$storedPath';
  }

  // ---- index -----------------------------------------------------------

  File _indexFile(Directory root) => File('${root.path}/index.json');

  Future<List<ScanDocument>> loadIndex() async {
    final root = await _root();
    final file = _indexFile(root);
    if (!await file.exists()) return <ScanDocument>[];
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <ScanDocument>[];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ScanDocument.fromJson(e as Map<String, dynamic>))
          .map((doc) => _withAbsolutePaths(doc, root.path))
          .toList();
    } catch (_) {
      // A corrupt index should not crash the app; start from an empty library.
      return <ScanDocument>[];
    }
  }

  Future<void> saveIndex(List<ScanDocument> documents) async {
    final root = await _root();
    final relative =
        documents.map((doc) => _withRelativePaths(doc, root.path)).toList();
    final json = jsonEncode(relative.map((d) => d.toJson()).toList());
    // Write to a temp file then rename over the target for an atomic-ish swap.
    final tmp = File('${root.path}/index.json.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_indexFile(root).path);
  }

  ScanDocument _withAbsolutePaths(ScanDocument doc, String rootPath) {
    return doc.copyWith(
      pages: doc.pages
          .map((pg) => pg.copyWith(
                sourceImagePath: _absolutize(pg.sourceImagePath, rootPath),
                processedImagePath: pg.processedImagePath == null
                    ? null
                    : _absolutize(pg.processedImagePath!, rootPath),
              ))
          .toList(),
      exportedPdfPath: doc.exportedPdfPath == null
          ? null
          : _absolutize(doc.exportedPdfPath!, rootPath),
    );
  }

  ScanDocument _withRelativePaths(ScanDocument doc, String rootPath) {
    return doc.copyWith(
      pages: doc.pages
          .map((pg) => pg.copyWith(
                sourceImagePath: _relativize(pg.sourceImagePath, rootPath),
                processedImagePath: pg.processedImagePath == null
                    ? null
                    : _relativize(pg.processedImagePath!, rootPath),
              ))
          .toList(),
      exportedPdfPath: doc.exportedPdfPath == null
          ? null
          : _relativize(doc.exportedPdfPath!, rootPath),
    );
  }

  // ---- image + pdf files ------------------------------------------------

  /// Copies a scanner temp file into the document's images dir, preserving the
  /// original extension. Returns the absolute destination path.
  Future<String> importSourceFile(
    String srcPath,
    String docId,
    String pageId,
  ) async {
    final dir = await _imagesDir(docId);
    final dot = srcPath.lastIndexOf('.');
    final ext = dot >= 0 ? srcPath.substring(dot) : '.jpg';
    final dest = '${dir.path}/${pageId}_src$ext';
    await File(srcPath).copy(dest);
    return dest;
  }

  /// Writes processed PNG bytes for a page. [token] makes the filename unique
  /// per processing run so the file path changes on every re-process — this is
  /// what invalidates Flutter's path-keyed image cache so a new filter result
  /// actually renders. Returns the absolute path.
  Future<String> saveProcessedBytes(
    String docId,
    String pageId,
    String token,
    Uint8List bytes,
  ) async {
    final dir = await _imagesDir(docId);
    final dest = '${dir.path}/${pageId}_proc_$token.png';
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  /// Deletes a single file by absolute path, if it exists.
  Future<void> deleteFileAt(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// Removes a document's entire images directory. Used to roll back a failed
  /// import whose files were written before any index entry existed.
  Future<void> deleteDocumentImages(String docId) async {
    final root = await _root();
    final dir = Directory('${root.path}/images/$docId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Persists exported PDF bytes. Returns the saved file.
  Future<File> writePdf(String docId, Uint8List bytes) async {
    final dir = await _pdfsDir();
    final file = File('${dir.path}/$docId.pdf');
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Removes all files (images + pdf) belonging to a document.
  Future<void> deleteDocument(ScanDocument doc) async {
    final root = await _root();
    final imagesDir = Directory('${root.path}/images/${doc.id}');
    if (await imagesDir.exists()) await imagesDir.delete(recursive: true);
    final pdf = File('${root.path}/pdfs/${doc.id}.pdf');
    if (await pdf.exists()) await pdf.delete();
  }

  /// Removes the source/processed files for a single removed page.
  Future<void> deletePageFiles(ScanPage page) async {
    final paths = <String?>[page.sourceImagePath, page.processedImagePath];
    for (final path in paths) {
      if (path == null) continue;
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }
}
