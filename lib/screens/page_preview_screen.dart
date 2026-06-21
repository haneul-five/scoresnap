import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_page.dart';

/// Full-screen, zoomable preview of a single scanned page.
class PagePreviewScreen extends StatelessWidget {
  const PagePreviewScreen({super.key, required this.page});

  final ScanPage page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            File(page.displayPath),
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
