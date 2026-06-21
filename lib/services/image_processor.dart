import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/scan_page.dart';

/// Isolate payload. Holds only data that can be sent across an isolate.
class _ProcessParams {
  const _ProcessParams(this.bytes, this.filter);

  final Uint8List bytes;
  final ImageFilterType filter;
}

/// On-device image processing. Converts a source image into the bytes that are
/// displayed and exported, according to the selected [ImageFilterType].
///
/// The heavy decode -> filter -> encode pipeline runs in a background isolate
/// via [compute] so the UI thread stays responsive on multi-megapixel photos.
class ImageProcessor {
  const ImageProcessor();

  /// Returns processed PNG bytes for [filter]. For [ImageFilterType.original]
  /// the source is re-encoded as PNG unchanged.
  Future<Uint8List> process(Uint8List sourceBytes, ImageFilterType filter) {
    return compute(_processSync, _ProcessParams(sourceBytes, filter));
  }

  /// Pure, isolate-safe processing entry point.
  static Uint8List _processSync(_ProcessParams params) {
    final decoded = img.decodeImage(params.bytes);
    if (decoded == null) {
      // Undecodable input: hand the original bytes back untouched.
      return params.bytes;
    }
    switch (params.filter) {
      case ImageFilterType.original:
        return img.encodePng(decoded);
      case ImageFilterType.grayscale:
        return img.encodePng(img.grayscale(decoded));
      case ImageFilterType.blackwhite:
        final gray = img.grayscale(decoded);
        // Denoise paper speckle without erasing thin staff lines.
        img.gaussianBlur(gray, radius: 1);
        // Boost contrast (adjustColor.contrast is a multiplier; 1.0 = no-op).
        img.adjustColor(gray, contrast: 1.3);
        // Cap the size before binarization to bound the Sauvola working buffers
        // (three full-resolution Float64 lists) on multi-megapixel photos.
        final work = _capLongestEdge(gray);
        final binary = _sauvolaThreshold(work);
        return img.encodePng(binary);
    }
  }

  /// Downscales [src] so its longest edge is at most [maxEdge], preserving the
  /// aspect ratio. Sheet music stays legible well under this size, while the
  /// pixel count (and thus the Sauvola buffers) stays bounded.
  static img.Image _capLongestEdge(img.Image src, {int maxEdge = 2400}) {
    final longest = math.max(src.width, src.height);
    if (longest <= maxEdge) return src;
    return src.width >= src.height
        ? img.copyResize(src, width: maxEdge)
        : img.copyResize(src, height: maxEdge);
  }

  /// Sauvola adaptive thresholding tuned for sheet music. Uses an integral
  /// image (summed-area table) so it is O(N) regardless of window size.
  ///
  /// Output is a single-channel image: 255 = paper (white), 0 = ink/notes.
  static img.Image _sauvolaThreshold(
    img.Image src, {
    int window = 25,
    double k = 0.34,
    double r = 128.0,
  }) {
    final w = src.width;
    final h = src.height;

    // 1) Luminance buffer in [0, 255]. Reuse one Pixel cursor to avoid
    //    allocating a Pixel object per pixel.
    final lum = Float64List(w * h);
    img.Pixel? cursor;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        cursor = src.getPixel(x, y, cursor);
        lum[y * w + x] = cursor.luminance.toDouble();
      }
    }

    // 2) Integral images of sum and sum-of-squares, sized (w+1) x (h+1).
    final iw = w + 1;
    final sum = Float64List(iw * (h + 1));
    final sqSum = Float64List(iw * (h + 1));
    for (var y = 1; y <= h; y++) {
      var rowSum = 0.0;
      var rowSq = 0.0;
      for (var x = 1; x <= w; x++) {
        final v = lum[(y - 1) * w + (x - 1)];
        rowSum += v;
        rowSq += v * v;
        sum[y * iw + x] = sum[(y - 1) * iw + x] + rowSum;
        sqSum[y * iw + x] = sqSum[(y - 1) * iw + x] + rowSq;
      }
    }

    // 3) Threshold each pixel against its local mean/std via the SAT.
    final out = img.Image(width: w, height: h, numChannels: 1);
    final rad = window ~/ 2;
    for (var y = 0; y < h; y++) {
      final y0 = (y - rad).clamp(0, h - 1);
      final y1 = (y + rad).clamp(0, h - 1);
      for (var x = 0; x < w; x++) {
        final x0 = (x - rad).clamp(0, w - 1);
        final x1 = (x + rad).clamp(0, w - 1);
        final area = (x1 - x0 + 1) * (y1 - y0 + 1);
        final a = y0 * iw + x0;
        final b = y0 * iw + (x1 + 1);
        final c = (y1 + 1) * iw + x0;
        final d = (y1 + 1) * iw + (x1 + 1);
        final s = sum[d] - sum[b] - sum[c] + sum[a];
        final sq = sqSum[d] - sqSum[b] - sqSum[c] + sqSum[a];
        final mean = s / area;
        final variance = (sq / area) - (mean * mean);
        final std = variance > 0 ? math.sqrt(variance) : 0.0;
        final threshold = mean * (1 + k * ((std / r) - 1));
        final value = lum[y * w + x] > threshold ? 255 : 0;
        out.setPixelRgb(x, y, value, value, value);
      }
    }
    return out;
  }
}
