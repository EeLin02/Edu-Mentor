import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  const ImagePreviewScreen({required this.imageUrl, super.key});

  bool get isPDF => imageUrl.toLowerCase().contains('.pdf');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Preview File"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: isPDF
            ? SfPdfViewer.network(imageUrl)
            : Hero(
          tag: imageUrl,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}
