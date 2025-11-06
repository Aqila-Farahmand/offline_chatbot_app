import 'dart:io';

Future<String> readCsvFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw ArgumentError('File not found at $filePath');
  }
  return await file.readAsString();
}
