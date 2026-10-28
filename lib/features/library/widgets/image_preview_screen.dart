import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../library_models.dart';

/// An image document read in the app: the bytes the API streamed for the preview, zoomable. Every other
/// format has no viewer in the app and opens in the phone's own apps.
class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key, required this.file, this.onDownload});

  final DocumentBytes file;

  /// The download glyph in the bar: takes a copy (counted as a download); hidden when null.
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          file.fileName,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (onDownload != null)
            IconButton(tooltip: 'Download', icon: const Icon(LucideIcons.download, size: 20), onPressed: onDownload),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(
              file.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(32),
                child: Text("This image can't be shown. Download it instead.", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
