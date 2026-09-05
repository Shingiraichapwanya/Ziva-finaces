import 'dart:typed_data';
import 'receipt_file_model.dart';

Future<UploadedReceiptFile?> pickReceiptFileWeb() async {
  return const UploadedReceiptFile(
    name: 'Woolworths_Invoice_ZAR_345.50.pdf',
    size: 42500,
    mimeType: 'application/pdf',
    textSnippet: 'Woolworths V&A Waterfront Total ZAR 345.50 Groceries',
  );
}

void registerDragDropListener({
  required void Function(UploadedReceiptFile file) onFileDropped,
  required void Function(bool isDragging) onDragStateChanged,
}) {
  // No-op on native platforms
}

void unregisterDragDropListener() {
  // No-op on native platforms
}

void downloadFileWeb({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  // No-op on native/test platforms
}

void downloadBytesWeb({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) {
  // No-op on native/test platforms
}
