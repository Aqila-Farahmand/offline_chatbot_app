import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  };

  static Future<void> downloadModel({
    required String modelId,
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    try {
      final modelInfo = availableModels[modelId];
      if (modelInfo == null) {
        onError('Model not found');
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
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
