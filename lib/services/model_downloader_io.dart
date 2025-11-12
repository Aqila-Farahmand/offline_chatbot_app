// IO implementation for native platforms (dart:io available)
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/bundle_utils.dart';
import 'model_downloader.dart';
import '../config/external_urls.dart';
import '../config/app_constants.dart';

class NativeFileOperations {
  static Future<void> downloadModelNative(
    ModelInfo modelInfo,
    Function(double) onProgress,
    Function() onComplete,
    Function(String) onError,
  ) async {
    try {
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

      http.StreamedResponse response;
      try {
        response = await http.Client()
            .send(http.Request('GET', Uri.parse(modelInfo.url)))
            .timeout(
              Duration(minutes: AppConstants.modelDownloadTimeoutMinutes),
              onTimeout: () {
                throw Exception(
                  'Download timeout: Model download took too long',
                );
              },
            );
      } catch (e) {
        if (e.toString().contains('SocketException') ||
            e.toString().contains('NetworkError')) {
          throw Exception(
            'Network error: Unable to download from ${modelInfo.url}. '
            'Please check your internet connection.',
          );
        }
        rethrow;
      }

      if (response.statusCode != 200) {
        // Handle 401 Unauthorized - requires Hugging Face authentication
        if (response.statusCode == 401) {
          // Extract model page URL from the download URL
          final uri = Uri.parse(modelInfo.url);
          final pathParts = uri.pathSegments;
          final modelPageUrl = ExternalUrls.getHuggingFaceModelPageUrl(
            pathParts,
          );

          throw Exception(
            'Authentication Required: This model requires a Hugging Face account to download.\n\n'
            'Please follow these steps:\n'
            '1. Visit ${ExternalUrls.huggingFaceJoin} to create a free account (or login at ${ExternalUrls.huggingFaceLogin})\n'
            '2. Accept the model\'s terms of use on its Hugging Face page\n'
            '3. Generate an access token at ${ExternalUrls.huggingFaceSettingsTokens}\n'
            '4. You may need to download the model manually from the Hugging Face website or use the token in your download request\n\n'
            'Model page: $modelPageUrl',
          );
        }

        throw Exception(
          'HTTP ${response.statusCode}: Failed to download model from ${modelInfo.url}',
        );
      }

      final totalBytes = response.contentLength ?? modelInfo.size;
      var receivedBytes = 0;

      final sink = file.openWrite();
      try {
        await response.stream
            .listen(
              (chunk) {
                sink.add(chunk);
                receivedBytes += chunk.length;
                final progress = receivedBytes / totalBytes;
                onProgress(progress.clamp(0.0, 1.0));
              },
              onDone: () async {
                await sink.close();
                onComplete();
              },
              onError: (error) {
                sink.close();
                try {
                  file.deleteSync();
                } catch (_) {}
                onError('Error downloading: $error');
              },
              cancelOnError: true,
            )
            .asFuture(); // Convert StreamSubscription to Future
      } catch (e) {
        sink.close();
        try {
          file.deleteSync();
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      onError('Native download failed: $e');
    }
  }
}
