// Stub file for web platform (dart:io not available)
// This file is used when dart:io is not available (web platform)

class NativeFileOperations {
  // Stub methods - these should never be called on web
  static Future<void> downloadModelNative(
    dynamic modelInfo,
    Function(double) onProgress,
    Function() onComplete,
    Function(String) onError,
  ) async {
    throw UnsupportedError('Native file operations not available on web');
  }
}
