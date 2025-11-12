// Model storage for web - uses Cache API (compatible with current implementation)
// Can be enhanced with IndexedDB in the future for larger storage limits

import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import '../config/path_configs.dart';

/// Storage for model files on web using Cache API
/// Cache API works well for most use cases and is simpler than IndexedDB
class ModelStorageWeb {
  static const String _cacheName = 'model-cache';

  /// Store a model file using Cache API
  static Future<void> storeModel({
    required String filename,
    required Uint8List data,
  }) async {
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final cachePath = '${AppPaths.modelPaths}$filename';
      final cacheKeyRequest = web.Request(cachePath.toJS);

      final cacheResponse = web.Response(
        data.toJS,
        web.ResponseInit(status: 200, statusText: 'OK'),
      );

      await cache.put(cacheKeyRequest, cacheResponse).toDart;

      debugPrint(
        'Model stored in cache: $filename (${(data.length / 1024 / 1024).toStringAsFixed(2)} MB)',
      );
    } catch (e) {
      debugPrint('Error storing model in cache: $e');
      rethrow;
    }
  }

  /// Retrieve a model file from Cache API
  static Future<Uint8List?> getModel(String filename) async {
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final cachePath = '${AppPaths.modelPaths}$filename';
      final cacheKeyRequest = web.Request(cachePath.toJS);

      final response = await cache.match(cacheKeyRequest).toDart;
      if (response == null) {
        return null;
      }

      // Convert Response body to Uint8List
      final body = await response.arrayBuffer().toDart;
      // Convert ArrayBuffer to Uint8List using ByteBuffer
      final byteBuffer = body.toDart;
      final bytes = Uint8List.view(byteBuffer);
      return bytes;
    } catch (e) {
      debugPrint('Error retrieving model from cache: $e');
      return null;
    }
  }

  /// Check if a model exists
  static Future<bool> hasModel(String filename) async {
    final model = await getModel(filename);
    return model != null;
  }

  /// Delete a model
  static Future<void> deleteModel(String filename) async {
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final cachePath = '${AppPaths.modelPaths}$filename';
      final cacheKeyRequest = web.Request(cachePath.toJS);

      await cache.delete(cacheKeyRequest).toDart;

      debugPrint('Model deleted from cache: $filename');
    } catch (e) {
      debugPrint('Error deleting model from cache: $e');
      rethrow;
    }
  }

  /// List all stored model filenames
  static Future<List<String>> listModels() async {
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final keys = await cache.keys().toDart;
      final List<web.Request> keysList = keys.toDart;

      final List<String> filenames = [];
      for (final request in keysList) {
        final url = request.url;
        // Extract filename from path
        if (url.contains(AppPaths.modelPaths)) {
          final filename = url.split('/').last;
          if (filename.endsWith('.gguf') ||
              filename.endsWith('.task') ||
              filename.endsWith('.litertlm')) {
            filenames.add(filename);
          }
        }
      }

      return filenames;
    } catch (e) {
      debugPrint('Error listing models from cache: $e');
      return [];
    }
  }

  /// Get storage usage estimate (approximate)
  static Future<int> getStorageSize() async {
    try {
      final models = await listModels();
      int totalSize = 0;

      for (final filename in models) {
        final model = await getModel(filename);
        if (model != null) {
          totalSize += model.length;
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('Error calculating storage size: $e');
      return 0;
    }
  }

  /// Clear all stored models
  static Future<void> clearAll() async {
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final keys = await cache.keys().toDart;
      final List<web.Request> keysList = keys.toDart;

      for (final request in keysList) {
        await cache.delete(request).toDart;
      }

      debugPrint('All models cleared from cache');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      rethrow;
    }
  }

  /// Get model path for use with MediaPipe (returns cache path)
  static String getModelPath(String filename) {
    return '${AppPaths.modelPaths}$filename';
  }
}
