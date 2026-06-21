import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Assembles processed page images into a multi-page PDF and shares/prints it.
class PdfService {
  const PdfService();

  /// Builds a PDF with one page per image, each page sized exactly to its
  /// image so there is no distortion or letterboxing.
  Future<Uint8List> buildPdf(List<Uint8List> pageImages) async {
    final doc = pw.Document(title: 'ScoreSnap');
    for (final bytes in pageImages) {
      final provider = pw.MemoryImage(bytes);
      final decoded = img.decodeImage(bytes);
      final format = decoded != null
          ? PdfPageFormat(
              decoded.width.toDouble(),
              decoded.height.toDouble(),
              marginAll: 0,
            )
          : PdfPageFormat.a4;
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) =>
              pw.Image(provider, fit: pw.BoxFit.contain),
        ),
      );
    }
    return doc.save();
  }

  /// Opens the native share sheet (this also covers "Save to Files"). [origin]
  /// is the share button's global rect, required on iPad to anchor the popover.
  Future<void> share(
    Uint8List bytes, {
    String filename = 'scoresnap.pdf',
    Rect? origin,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: filename, bounds: origin);
  }

  /// Opens the OS print dialog.
  Future<void> printDoc(Uint8List bytes, {String name = 'ScoreSnap'}) async {
    await Printing.layoutPdf(
      name: name,
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }
}
