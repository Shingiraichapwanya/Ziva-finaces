// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'receipt_file_model.dart';

StreamSubscription<html.MouseEvent>? _dragOverSub;
StreamSubscription<html.MouseEvent>? _dropSub;
StreamSubscription<html.MouseEvent>? _dragLeaveSub;

/// Triggers browser native file selection modal for images and PDF receipts.
Future<UploadedReceiptFile?> pickReceiptFileWeb() async {
  final completer = Completer<UploadedReceiptFile?>();

  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/*,.pdf,application/pdf'
    ..multiple = false;

  uploadInput.onChange.listen((event) async {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((e) {
      final dynamic result = reader.result;
      Uint8List? bytes;
      if (result is ByteBuffer) {
        bytes = result.asUint8List();
      } else if (result is Uint8List) {
        bytes = result;
      }

      completer.complete(UploadedReceiptFile(
        name: file.name,
        size: file.size,
        mimeType: file.type,
        bytes: bytes,
        textSnippet: file.name,
      ));
    });

    reader.onError.listen((e) {
      completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
  });

  uploadInput.click();
  return completer.future;
}

/// Registers global drag-and-drop listeners on the browser DOM.
void registerDragDropListener({
  required void Function(UploadedReceiptFile file) onFileDropped,
  required void Function(bool isDragging) onDragStateChanged,
}) {
  unregisterDragDropListener();

  _dragOverSub = html.window.onDragOver.listen((event) {
    event.preventDefault();
    onDragStateChanged(true);
  });

  _dragLeaveSub = html.window.onDragLeave.listen((event) {
    event.preventDefault();
    onDragStateChanged(false);
  });

  _dropSub = html.window.onDrop.listen((event) {
    event.preventDefault();
    onDragStateChanged(false);

    final dt = event.dataTransfer;
    if (dt.files == null || dt.files!.isEmpty) return;

    final file = dt.files![0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((e) {
      final dynamic result = reader.result;
      Uint8List? bytes;
      if (result is ByteBuffer) {
        bytes = result.asUint8List();
      } else if (result is Uint8List) {
        bytes = result;
      }

      onFileDropped(UploadedReceiptFile(
        name: file.name,
        size: file.size,
        mimeType: file.type,
        bytes: bytes,
        textSnippet: file.name,
      ));
    });

    reader.readAsArrayBuffer(file);
  });
}

/// Cleans up drag-and-drop subscriptions.
void unregisterDragDropListener() {
  _dragOverSub?.cancel();
  _dragOverSub = null;
  _dragLeaveSub?.cancel();
  _dragLeaveSub = null;
  _dropSub?.cancel();
  _dropSub = null;
}

/// Downloads text/csv content as a local file in browser
void downloadFileWeb({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  final bytes = utf8.encode(content);
  downloadBytesWeb(filename: filename, bytes: Uint8List.fromList(bytes), mimeType: mimeType);
}

/// Downloads binary bytes as a local file in browser
void downloadBytesWeb({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
