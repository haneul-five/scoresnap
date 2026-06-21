import 'package:flutter/foundation.dart';

/// The processing filter applied to a scanned page before display/export.
enum ImageFilterType {
  /// The unmodified cropped/perspective-corrected source image.
  original,

  /// Grayscale conversion.
  grayscale,

  /// Adaptive (Sauvola) black & white, tuned for musical notation.
  blackwhite,
}

/// One scanned page within a [ScanDocument]. Immutable.
@immutable
class ScanPage {
  const ScanPage({
    required this.id,
    required this.sourceImagePath,
    this.processedImagePath,
    this.filter = ImageFilterType.blackwhite,
  });

  /// Stable unique id (uuid v4).
  final String id;

  /// Persisted copy of the scanner's cropped/perspective-corrected output.
  final String sourceImagePath;

  /// Binarized/processed PNG produced by the image processor. Null when the
  /// filter is [ImageFilterType.original] (the source is shown directly) or
  /// before processing has run.
  final String? processedImagePath;

  /// The currently selected filter for this page.
  final ImageFilterType filter;

  /// Path of the image to display and export: the processed image when
  /// available, otherwise the original source.
  String get displayPath => processedImagePath ?? sourceImagePath;

  ScanPage copyWith({
    String? id,
    String? sourceImagePath,
    String? processedImagePath,
    bool clearProcessed = false,
    ImageFilterType? filter,
  }) {
    return ScanPage(
      id: id ?? this.id,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      processedImagePath: clearProcessed
          ? null
          : (processedImagePath ?? this.processedImagePath),
      filter: filter ?? this.filter,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceImagePath': sourceImagePath,
        'processedImagePath': processedImagePath,
        'filter': filter.name,
      };

  factory ScanPage.fromJson(Map<String, dynamic> json) {
    return ScanPage(
      id: json['id'] as String,
      sourceImagePath: json['sourceImagePath'] as String,
      processedImagePath: json['processedImagePath'] as String?,
      filter: ImageFilterType.values.firstWhere(
        (f) => f.name == json['filter'],
        orElse: () => ImageFilterType.blackwhite,
      ),
    );
  }
}
