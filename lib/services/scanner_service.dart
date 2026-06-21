import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart' show PlatformException;

/// Raised when the native document scanner cannot run — e.g. it is unavailable,
/// the device has too little RAM, or Google Play services are missing/outdated
/// on Android. The UI surfaces [message] to the user.
class ScannerException implements Exception {
  ScannerException(this.message);

  final String message;

  @override
  String toString() => 'ScannerException: $message';
}

/// Thin wrapper around the native on-device document scanner — Google ML Kit
/// Document Scanner on Android and Apple VisionKit on iOS — exposed by the
/// cunning_document_scanner plugin. The native UI performs camera capture,
/// automatic edge detection and perspective correction; this returns the file
/// paths of the resulting cropped images.
class ScannerService {
  const ScannerService();

  /// Launches the system scanner and returns the file paths of the cropped,
  /// perspective-corrected page images. Returns an empty list when the user
  /// cancels. Throws [ScannerException] when the scanner cannot start.
  Future<List<String>> scanPages({int maxPages = 30}) async {
    try {
      final paths = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        isGalleryImportAllowed: true,
        iosScannerOptions: IosScannerOptions(
          // Lossless source keeps thin staff lines crisp for binarization.
          imageFormat: IosImageFormat.png,
        ),
      );
      return paths ?? <String>[];
    } on PlatformException catch (e) {
      throw ScannerException(
        e.message ??
            'The document scanner could not be started on this device.',
      );
    }
  }
}
