import 'package:flutter/material.dart';

import '../models/scan_page.dart';

/// Material 3 segmented control for choosing the page filter applied to the
/// whole document.
class FilterSelector extends StatelessWidget {
  const FilterSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ImageFilterType value;
  final ValueChanged<ImageFilterType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ImageFilterType>(
      segments: const [
        ButtonSegment(
          value: ImageFilterType.original,
          label: Text('Original'),
          icon: Icon(Icons.image_outlined),
        ),
        ButtonSegment(
          value: ImageFilterType.grayscale,
          label: Text('Gray'),
          icon: Icon(Icons.gradient),
        ),
        ButtonSegment(
          value: ImageFilterType.blackwhite,
          label: Text('B&W'),
          icon: Icon(Icons.contrast),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}
