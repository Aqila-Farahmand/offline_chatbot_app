// Manual file upload for web users
// Allows users to upload model files they download externally

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'model_storage_web.dart';

class ModelUploadWeb {
  /// Upload a model file from user's device
  /// Returns the filename if successful, null if cancelled, throws on error
  static Future<String?> uploadModel({
    required Function(double) onProgress,
  }) async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf', 'task', 'litertlm'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled
        return null;
      }

      final file = result.files.first;

      if (file.bytes == null) {
        throw Exception(
          'File data is null. Please try selecting the file again.',
        );
      }

      final filename = file.name;
      final bytes = file.bytes!;

      debugPrint(
        'Uploading model: $filename (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)',
      );

      // Validate file extension
      if (!filename.endsWith('.gguf') &&
          !filename.endsWith('.task') &&
          !filename.endsWith('.litertlm')) {
        throw Exception(
          'Invalid file type. Please select a .gguf, .task, or .litertlm file.',
        );
      }

      // Validate file size (warn if too large, but allow)
      const maxRecommendedSize = 5 * 1024 * 1024 * 1024; // 5GB
      if (bytes.length > maxRecommendedSize) {
        debugPrint(
          'Warning: File is very large (${(bytes.length / 1024 / 1024 / 1024).toStringAsFixed(2)} GB). '
          'This may cause browser performance issues.',
        );
      }

      // Show progress
      onProgress(0.5);

      // Store in IndexedDB
      final uint8List = Uint8List.fromList(bytes);
      await ModelStorageWeb.storeModel(filename: filename, data: uint8List);

      onProgress(1.0);

      debugPrint('Model uploaded successfully: $filename');
      return filename;
    } catch (e) {
      debugPrint('Error uploading model: $e');
      rethrow;
    }
  }

  /// Check if manual upload is supported on this platform
  static bool get isSupported => kIsWeb;
}
