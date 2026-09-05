// ignore_for_file: avoid_print
import 'dart:io';

/// Automated setup script to verify and provision sqflite_sw.js and sqlite3.wasm
/// for Flutter Web builds.
void main() async {
  final webDir = Directory('web');
  if (!webDir.existsSync()) {
    webDir.createSync(recursive: true);
  }

  final swFile = File('web/sqflite_sw.js');
  final wasmFile = File('web/sqlite3.wasm');

  if (swFile.existsSync() && wasmFile.existsSync()) {
    print('[setup_web] sqflite_sw.js and sqlite3.wasm are present in web/ directory.');
    return;
  }

  print('[setup_web] Worker scripts missing in web/. Running sqflite_common_ffi_web:setup...');
  final result = await Process.run(
    'dart',
    ['run', 'sqflite_common_ffi_web:setup'],
    runInShell: true,
  );

  print(result.stdout);
  if (result.exitCode != 0) {
    print('[setup_web] Error running setup: ${result.stderr}');
    exit(result.exitCode);
  } else {
    print('[setup_web] Successfully provisioned sqflite_sw.js and sqlite3.wasm in web/.');
  }
}
