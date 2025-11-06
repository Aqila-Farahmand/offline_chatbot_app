import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'dart:js_interop';

// Conditional import for dart:io (not available on web)
import 'model_downloader_stub.dart'
    if (dart.library.io) 'model_downloader_io.dart';

class ModelDownloader {
  static const Map<String, ModelInfo> availableModels = {
    'gemma-2b': ModelInfo(
      name: 'Gemma 2B',
      filename: 'gemma-2b-q4.gguf',
      size: 2100000000, // ~2.1GB
      url:
          'https://huggingface.co/google/gemma-2b-it/resolve/main/gemma-2b-q4.gguf',
      description: 'Smaller, faster model suitable for most tasks',
      contextSize: 8192,
    ),
    // Sub-1GB GGUF suggestions
    'tinyllama-1_1b-chat-q4': ModelInfo(
      name: 'TinyLlama 1.1B Chat (Q4_K_M)',
      filename: 'tinyllama-1.1b-chat.Q4_K_M.gguf',
      size: 700000000, // ~0.7GB
      url:
          'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat.Q4_K_M.gguf',
      description: 'Very small chat model, good for speed and low memory',
      contextSize: 4096,
    ),
    'qwen2.5-1.5b-instruct': ModelInfo(
      name: 'Qwen2.5-1.5B-Instruct',
      filename: 'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task',
      size: 1600000000, // ~1.6GB (approx; actual may vary)
      url:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task',
      description: 'MediaPipe .task optimized for Android (INT4)',
      contextSize: 2048,
    ),
    // Web-specific models (smaller, optimized for browser)
    'gemma-3n-E2B-it-litert-lm': ModelInfo(
      name: 'Gemma 3N E2B it litert lm',
      filename: 'gemma-3n-E2B-it-int4-Web.litertlm',
      size: 3040000000, // ~3.04GB
      url:
          'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4-Web.litertlm',
      description: 'MediaPipe .task optimized for web browsers',
      contextSize: 2048,
    ),
  };

  /// Get models compatible with the current platform
  static Map<String, ModelInfo> getCompatibleModels() {
    if (kIsWeb) {
      // Web: .task, .litertlm, and other web-compatible formats
      return Map.fromEntries(
        availableModels.entries.where(
          (e) =>
              e.value.filename.endsWith('.task') ||
              e.value.filename.endsWith('.litertlm'),
        ),
      );
    } else {
      // Native platforms: show all models (users can download what they need)
      // Android users will download .task, desktop users will download .gguf
      return availableModels;
    }
  }

  /// Get models compatible with a specific platform type
  static Map<String, ModelInfo> getModelsForPlatform({
    bool forWeb = false,
    bool forAndroid = false,
    bool forDesktop = false,
  }) {
    if (forWeb) {
      // Web: .task, .litertlm, and other web-compatible formats
      return Map.fromEntries(
        availableModels.entries.where(
          (e) =>
              e.value.filename.endsWith('.task') ||
              e.value.filename.endsWith('.litertlm'),
        ),
      );
    } else if (forAndroid) {
      // Android: .task models
      return Map.fromEntries(
        availableModels.entries.where(
          (e) => e.value.filename.endsWith('.task'),
        ),
      );
    } else if (forDesktop) {
      // Desktop: only .gguf models
      return Map.fromEntries(
        availableModels.entries.where(
          (e) => e.value.filename.endsWith('.gguf'),
        ),
      );
    }
    return availableModels;
  }

  static Future<void> downloadModel({
    required String modelId,
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    try {
      final modelInfo = availableModels[modelId];
      if (modelInfo == null) {
        onError('Model not found: $modelId');
        return;
      }

      // Validate URL format
      try {
        final uri = Uri.parse(modelInfo.url);
        if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw Exception('Invalid URL scheme: ${modelInfo.url}');
        }
        print('Downloading model: ${modelInfo.name}');
        print('URL: ${modelInfo.url}');
        print('Expected size: ${modelInfo.formattedSize}');
      } catch (e) {
        onError('Invalid model URL: ${modelInfo.url}. Error: $e');
        return;
      }

      if (kIsWeb) {
        await _downloadModelWeb(modelInfo, onProgress, onComplete, onError);
      } else {
        await _downloadModelNative(modelInfo, onProgress, onComplete, onError);
      }
    } catch (e) {
      onError('Download failed: $e');
    }
  }

  static Future<void> _downloadModelNative(
    ModelInfo modelInfo,
    Function(double) onProgress,
    Function() onComplete,
    Function(String) onError,
  ) async {
    // Use conditional implementation based on platform
    if (kIsWeb) {
      throw UnsupportedError('Native download not available on web');
    }
    await NativeFileOperations.downloadModelNative(
      modelInfo,
      onProgress,
      onComplete,
      onError,
    );
  }

  static Future<void> _downloadModelWeb(
    ModelInfo modelInfo,
    Function(double) onProgress,
    Function() onComplete,
    Function(String) onError,
  ) async {
    try {
      // Check if model already exists in cache
      final cache = await web.window.caches.open('model-cache').toDart;
      final cachePath = 'assets/models/${modelInfo.filename}';
      // Use Request object to match the cache key format used when storing
      final cacheKeyRequest = web.Request(cachePath.toJS);
      final existingResponse = await cache.match(cacheKeyRequest).toDart;

      if (existingResponse != null) {
        onError('Model already exists in cache');
        return;
      }

      // Note: Download requires internet connection. Once downloaded, models work offline
      // via Cache API. Network errors will be caught and reported below.

      // Stream download for progress tracking using http.Client
      // HuggingFace URLs may redirect, so we need to follow redirects
      http.StreamedResponse? streamedResponse;
      try {
        print('Starting download from: ${modelInfo.url}');
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(modelInfo.url));

        // Add headers to help with CORS and downloads
        request.headers.addAll({
          'User-Agent': 'Mozilla/5.0 (compatible; Flutter)',
          'Accept': '*/*',
        });

        var response = await client
            .send(request)
            .timeout(
              const Duration(minutes: 30), // 30 minute timeout for large files
              onTimeout: () {
                client.close();
                throw Exception(
                  'Download timeout: Model download took too long. '
                  'Please check your internet connection and try again.',
                );
              },
            );

        // Handle redirects (HuggingFace often uses 302/301 redirects)
        if (response.statusCode == 301 || response.statusCode == 302) {
          final location = response.headers['location'];
          if (location != null) {
            print('Following redirect to: $location');
            client.close();
            final redirectRequest = http.Request('GET', Uri.parse(location));
            redirectRequest.headers.addAll({
              'User-Agent': 'Mozilla/5.0 (compatible; Flutter)',
              'Accept': '*/*',
            });
            streamedResponse = await http.Client().send(redirectRequest);
          } else {
            streamedResponse = response;
          }
        } else {
          streamedResponse = response;
        }
      } catch (e) {
        final errorStr = e.toString();
        print('Download error: $errorStr');
        if (errorStr.contains('CORS') ||
            errorStr.contains('Failed to load') ||
            errorStr.contains('NetworkError') ||
            errorStr.contains('SocketException') ||
            errorStr.contains('XMLHttpRequest')) {
          throw Exception(
            'Network/CORS error: Unable to download from ${modelInfo.url}. '
            'This may be a CORS issue. HuggingFace CDN should support CORS. '
            'Please check your internet connection and try again. '
            'Note: Download requires internet, but once downloaded, models work offline.',
          );
        }
        rethrow;
      }

      print('Response status: ${streamedResponse.statusCode}');
      print('Content-Length: ${streamedResponse.contentLength}');

      if (streamedResponse.statusCode != 200) {
        // Handle 401 Unauthorized - requires Hugging Face authentication
        if (streamedResponse.statusCode == 401) {
          // Extract model page URL from the download URL
          final uri = Uri.parse(modelInfo.url);
          final pathParts = uri.pathSegments;
          String modelPageUrl = 'https://huggingface.co';
          if (pathParts.length >= 2) {
            modelPageUrl =
                'https://huggingface.co/${pathParts[0]}/${pathParts[1]}';
          }

          throw Exception(
            'Authentication Required: This model requires a Hugging Face account to download.\n\n'
            'Please follow these steps:\n'
            '1. Visit https://huggingface.co/join to create a free account (or login at https://huggingface.co/login)\n'
            '2. Accept the model\'s terms of use on its Hugging Face page\n'
            '3. Generate an access token at https://huggingface.co/settings/tokens\n'
            '4. Note: For web downloads, you may need to download the model manually from the Hugging Face website\n\n'
            'Model page: $modelPageUrl',
          );
        }

        // Try to get error body for better debugging
        String? errorBody;
        try {
          final errorBytes = await streamedResponse.stream.toList();
          errorBody = String.fromCharCodes(errorBytes.expand((x) => x));
        } catch (_) {}

        throw Exception(
          'HTTP ${streamedResponse.statusCode}: Failed to download model from ${modelInfo.url}'
          '${errorBody != null ? '\nError details: ${errorBody.substring(0, errorBody.length > 200 ? 200 : errorBody.length)}' : ''}',
        );
      }

      final contentLength = streamedResponse.contentLength ?? modelInfo.size;
      List<int> bytes = [];

      try {
        // Read response in chunks to track progress
        int chunkCount = 0;
        await for (final chunk in streamedResponse.stream) {
          bytes.addAll(chunk);
          chunkCount++;
          if (contentLength > 0) {
            final progress = bytes.length / contentLength;
            onProgress(progress.clamp(0.0, 1.0));
            // Log progress every 10MB or every 100 chunks
            if (chunkCount % 100 == 0 ||
                bytes.length % (10 * 1024 * 1024) == 0) {
              print(
                'Download progress: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB / ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB',
              );
            }
          }
        }
        print(
          'Download complete: ${bytes.length} bytes received in $chunkCount chunks',
        );
      } catch (e) {
        print('Error reading stream: $e');
        throw Exception('Error reading download stream: $e');
      }

      if (bytes.isEmpty) {
        throw Exception(
          'Downloaded file is empty. The URL may be incorrect or the file may not exist.',
        );
      }

      print('Downloaded ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

      // Convert List<int> to Uint8List for ArrayBuffer/Blob creation
      final Uint8List downloadedData = Uint8List.fromList(bytes);

      try {
        print(
          'Caching model: ${modelInfo.filename} (${(downloadedData.length / 1024 / 1024).toStringAsFixed(2)} MB)',
        );

        // Create a web.Response object to store in the Cache API
        // The Response constructor accepts the body as JSAny (Uint8List.toJS works)
        final web.Response cacheResponse = web.Response(
          downloadedData.toJS,
          web.ResponseInit(status: 200, statusText: 'OK'),
        );

        // Use the web.Request object as the key and the cacheResponse as the value
        await cache.put(cacheKeyRequest, cacheResponse).toDart;
        print('Model successfully cached: $cachePath');
      } catch (e) {
        print('Cache error: $e');
        throw Exception(
          'Error caching model: $e. '
          'The file may be too large for browser cache (${(downloadedData.length / 1024 / 1024).toStringAsFixed(2)} MB). '
          'Browser cache limits vary by browser.',
        );
      }

      print('Download and cache completed successfully');
      onComplete();
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Web download failed')) {
        onError(errorMessage);
      } else {
        onError('Web download failed: $errorMessage');
      }
    }
  }
}

class ModelInfo {
  final String name;
  final String filename;
  final int size;
  final String url;
  final String description;
  final int contextSize;

  const ModelInfo({
    required this.name,
    required this.filename,
    required this.size,
    required this.url,
    required this.description,
    required this.contextSize,
  });

  String get formattedSize {
    final sizeInGb = size / 1000000000;
    return '${sizeInGb.toStringAsFixed(1)}GB';
  }
}
