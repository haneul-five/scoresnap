import 'package:flutter/foundation.dart';

import 'scan_page.dart';

/// A multi-page scanned document. Immutable.
@immutable
class ScanDocument {
  const ScanDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pages,
    this.exportedPdfPath,
  });

  /// Stable unique id (uuid v7 — time-sortable).
  final String id;

  /// User-facing title.
  final String title;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ordered pages of the document.
  final List<ScanPage> pages;

  /// Path of the last exported PDF, if any. Cleared whenever the pages change.
  final String? exportedPdfPath;

  int get pageCount => pages.length;

  /// First page's display image — used for the library thumbnail. Null when
  /// the document has no pages.
  String? get thumbnailPath => pages.isEmpty ? null : pages.first.displayPath;

  ScanDocument copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ScanPage>? pages,
    String? exportedPdfPath,
    bool clearExportedPdf = false,
  }) {
    return ScanDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
      exportedPdfPath: clearExportedPdf
          ? null
          : (exportedPdfPath ?? this.exportedPdfPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pages': pages.map((p) => p.toJson()).toList(),
        'exportedPdfPath': exportedPdfPath,
      };

  factory ScanDocument.fromJson(Map<String, dynamic> json) {
    return ScanDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pages: (json['pages'] as List<dynamic>)
          .map((e) => ScanPage.fromJson(e as Map<String, dynamic>))
          .toList(),
      exportedPdfPath: json['exportedPdfPath'] as String?,
    );
  }
}
