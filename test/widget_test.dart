// Unit tests for the ScoreSnap data models (JSON round-trip + copyWith).

import 'package:flutter_test/flutter_test.dart';
import 'package:scoresnap/models/scan_document.dart';
import 'package:scoresnap/models/scan_page.dart';

void main() {
  group('ScanPage', () {
    test('JSON round-trip preserves fields', () {
      const page = ScanPage(
        id: 'p1',
        sourceImagePath: 'images/d1/p1_src.png',
        processedImagePath: 'images/d1/p1_proc.png',
        filter: ImageFilterType.blackwhite,
      );
      final restored = ScanPage.fromJson(page.toJson());
      expect(restored.id, page.id);
      expect(restored.sourceImagePath, page.sourceImagePath);
      expect(restored.processedImagePath, page.processedImagePath);
      expect(restored.filter, ImageFilterType.blackwhite);
    });

    test('copyWith can clear the processed path', () {
      const page = ScanPage(
        id: 'p1',
        sourceImagePath: 'a.png',
        processedImagePath: 'b.png',
      );
      final cleared = page.copyWith(clearProcessed: true);
      expect(cleared.processedImagePath, isNull);
      expect(cleared.displayPath, 'a.png');
    });

    test('unknown filter falls back to blackwhite', () {
      final restored = ScanPage.fromJson({
        'id': 'p1',
        'sourceImagePath': 'a.png',
        'processedImagePath': null,
        'filter': 'bogus',
      });
      expect(restored.filter, ImageFilterType.blackwhite);
    });
  });

  group('ScanDocument', () {
    ScanDocument sample() => ScanDocument(
          id: 'd1',
          title: 'Test',
          createdAt: DateTime.parse('2026-06-21T10:00:00.000'),
          updatedAt: DateTime.parse('2026-06-21T11:00:00.000'),
          pages: const [
            ScanPage(id: 'p1', sourceImagePath: 'a.png'),
            ScanPage(id: 'p2', sourceImagePath: 'b.png'),
          ],
        );

    test('JSON round-trip preserves pages and timestamps', () {
      final doc = sample();
      final restored = ScanDocument.fromJson(doc.toJson());
      expect(restored.id, 'd1');
      expect(restored.title, 'Test');
      expect(restored.pageCount, 2);
      expect(restored.createdAt, doc.createdAt);
      expect(restored.updatedAt, doc.updatedAt);
      expect(restored.pages.map((p) => p.id), ['p1', 'p2']);
    });

    test('thumbnailPath uses the first page display path', () {
      expect(sample().thumbnailPath, 'a.png');
    });

    test('clearExportedPdf removes the exported path', () {
      final doc = sample().copyWith(exportedPdfPath: 'pdfs/d1.pdf');
      expect(doc.exportedPdfPath, 'pdfs/d1.pdf');
      expect(doc.copyWith(clearExportedPdf: true).exportedPdfPath, isNull);
    });
  });
}
