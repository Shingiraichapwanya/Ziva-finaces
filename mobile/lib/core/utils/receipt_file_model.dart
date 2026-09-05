import 'package:flutter/foundation.dart';

class UploadedReceiptFile {
  final String name;
  final int size;
  final String mimeType;
  final Uint8List? bytes;
  final String? textSnippet;

  const UploadedReceiptFile({
    required this.name,
    required this.size,
    required this.mimeType,
    this.bytes,
    this.textSnippet,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
