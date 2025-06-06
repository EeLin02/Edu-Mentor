import 'package:flutter/material.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  const ImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Preview Image"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Hero(
          tag: imageUrl,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}
