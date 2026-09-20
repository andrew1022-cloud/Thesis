import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../widgets/home_widgets.dart' show kMaroon;

/// Full-screen viewer for a lesson's original PDF, streamed from its
/// Firebase Storage download URL (set on the lesson doc as `pdfUrl`
/// by ContentController when an admin publishes a lesson from a PDF
/// upload). This shows the actual paginated document — the
/// LessonScreen's "content" text is a separate, extracted-text copy
/// used for the in-app reading view and search/offline caching.
class PdfViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.url,
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
      body: SfPdfViewer.network(
        url,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
      ),
    );
  }
}
