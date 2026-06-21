import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Picks one or more images from the photo gallery and lets the user
/// crop/rotate each before returning their file paths. Works on both iOS and
/// Android — unlike the native document scanner's gallery import, which iOS
/// (VisionKit) silently ignores. Cropped output feeds the same processing
/// pipeline as scanned pages.
class GalleryService {
  const GalleryService();

  /// Returns the cropped file paths, in pick order. Returns an empty list if
  /// the user picks nothing; images whose crop is cancelled are skipped.
  Future<List<String>> pickAndCropImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return <String>[];

    final cropper = ImageCropper();
    final results = <String>[];
    for (final image in picked) {
      final cropped = await cropper.cropImage(
        sourcePath: image.path,
        // Lossless intermediate so thin staff lines survive into binarization.
        compressFormat: ImageCompressFormat.png,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop sheet music',
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop sheet music',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );
      if (cropped != null) results.add(cropped.path);
    }
    return results;
  }
}
