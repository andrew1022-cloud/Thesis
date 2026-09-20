import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../widgets/home_widgets.dart' show kMaroon;

/// Full-screen viewer for a lesson's original PDF. The bytes are the
/// PDF already reassembled from Firestore chunks by LessonPdfService
/// (see LessonController), so opening full screen doesn't download
/// anything again.
class PdfViewerScreen extends StatelessWidget {
  final Uint8List bytes;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.bytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: kMaroon,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SfPdfViewer.memory(
        bytes,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
      ),
    );
  }
}
