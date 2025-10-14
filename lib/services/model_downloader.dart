import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../utils/bundle_utils.dart';

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
    'gemma-7b': ModelInfo(
      name: 'Gemma 7B',
      filename: 'gemma-7b-q4.gguf',
      size: 7300000000, // ~7.3GB
      url:
          'https://huggingface.co/google/gemma-7b-it/resolve/main/gemma-7b-q4.gguf',
      description: 'Larger model with better accuracy',
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
    'qwen2-0_5b-instruct-q4': ModelInfo(
      name: 'Qwen2 0.5B Instruct (Q4_K_M)',
      filename: 'qwen2-0_5b-instruct.Q4_K_M.gguf',
      size: 600000000, // ~0.6GB
      url:
          'https://huggingface.co/TheBloke/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct.Q4_K_M.gguf',
      description: 'Compact instruction-tuned model under 1GB',
      contextSize: 4096,
    ),
    // Android MediaPipe .task examples (text generation). Ensure these are .task files.
    // These entries are intended for Android use with MediaPipe; they will also download on other platforms
    // but only Android uses .task in the current pipeline.
    'android-gemma-2b-task': ModelInfo(
      name: 'Android: Gemma 2B (task)',
      filename: 'gemma-2b-it-int4.task',
      size: 1200000000, // ~1.2GB (approx; actual may vary)
      url:
          'https://storage.googleapis.com/mediapipe-tasks/text/gemma2b_it_int4.task',
      description: 'MediaPipe .task optimized for Android (INT4)',
      contextSize: 2048,
    ),
    'android-qwen-0_5b-task': ModelInfo(
      name: 'Android: Qwen 0.5B (task)',
      filename: 'qwen-0_5b-it-int4.task',
      size: 600000000, // ~0.6GB (approx)
      url:
          'https://storage.googleapis.com/mediapipe-tasks/text/qwen0_5b_it_int4.task',
      description: 'MediaPipe .task smaller model for Android',
      contextSize: 2048,
    ),
  };

  static Future<void> downloadModel({
    required String modelId,
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    try {
      if (kIsWeb) {
        onError('Downloading models is not supported on web');
        return;
      }
      final modelInfo = availableModels[modelId];
      if (modelInfo == null) {
        onError('Model not found');
        return;
      }

      final modelsDirPath = await BundleUtils.getModelsDirectory();
      final modelsDir = Directory(modelsDirPath);
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final file = File('${modelsDir.path}/${modelInfo.filename}');
      if (await file.exists()) {
        onError('Model already exists');
        return;
      }

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(modelInfo.url)),
      );

      final totalBytes = response.contentLength ?? modelInfo.size;
      var receivedBytes = 0;

      final sink = file.openWrite();
      await response.stream
          .listen(
            (chunk) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              final progress = receivedBytes / totalBytes;
              onProgress(progress);
            },
            onDone: () async {
              await sink.close();
              onComplete();
            },
            onError: (error) {
              sink.close();
              file.deleteSync();
              onError(error.toString());
            },
            cancelOnError: true,
          )
          .asFuture(); // Convert StreamSubscription to Future
    } catch (e) {
      onError(e.toString());
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
