import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/llm_model.dart';
import '../config/path_configs.dart';

class ModelManager extends ChangeNotifier {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  List<LLMModel> _availableModels = [];
  LLMModel? _selectedModel;
  double _downloadProgress = 0.0;

  List<LLMModel> get availableModels => _availableModels;
  LLMModel? get selectedModel => _selectedModel;
  double get downloadProgress => _downloadProgress;

  Future<void> initialize() async {
    try {
      await _scanBundledAssets();
    } catch (e) {
      debugPrint('Error initializing ModelManager (web): $e');
      rethrow;
    }
  }

  Future<void> _scanBundledAssets() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);
      final String modelPath = AppPaths.modelPaths;

      // Get bundled model paths
      final modelAssetPaths = manifestMap.keys.where(
        (assetPath) =>
            assetPath.startsWith(modelPath) &&
            (assetPath.endsWith('.gguf') || assetPath.endsWith('.task')),
      );

      // Check Cache API for downloaded models
      List<String> cachedModelPaths = [];
      if (kIsWeb) {
        try {
          final cache = await web.window.caches.open('model-cache').toDart;
          final keys = await cache.keys().toDart;
          // Convert JSArray to Dart List first, then extract URLs
          final List<web.Request> keysList = keys.toDart;
          cachedModelPaths = keysList
              .map((request) => request.url)
              .where((key) => key.endsWith('.gguf') || key.endsWith('.task'))
              .toList();
        } catch (e) {
          debugPrint('Error checking cache: $e');
        }
      }

      _availableModels = [];

      // Add bundled models
      for (final assetPath in modelAssetPaths) {
        final filename = assetPath.split('/').last;
        final modelName = filename
            .replaceAll('.gguf', '')
            .replaceAll('.task', '');
        final isTask = filename.endsWith('.task');
        _availableModels.add(
          LLMModel(
            name: modelName,
            filename: filename,
            description: isTask
                ? 'MediaPipe task asset (web)'
                : 'Bundled model asset (web)',
            contextSize: 2048,
            isDownloaded: true,
          ),
        );
      }

      // Add cached/downloaded models
      for (final cachePath in cachedModelPaths) {
        final filename = cachePath.split('/').last;
        if (!_availableModels.any((m) => m.filename == filename)) {
          final modelName = filename
              .replaceAll('.gguf', '')
              .replaceAll('.task', '');
          final isTask = filename.endsWith('.task');
          _availableModels.add(
            LLMModel(
              name: modelName,
              filename: filename,
              description: isTask
                  ? 'Downloaded MediaPipe task (cached)'
                  : 'Downloaded model (cached)',
              contextSize: 2048,
              isDownloaded: true,
            ),
          );
        }
      }

      if (_availableModels.isNotEmpty) {
        _selectedModel ??= _availableModels.first;
      } else {
        _selectedModel = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error scanning assets: $e');
      rethrow;
    }
  }

  Future<void> rescanModels() async {
    await _scanBundledAssets();
  }

  Future<String?> getSelectedModelPath() async {
    if (_selectedModel == null) return null;

    // Check cache first for downloaded models
    if (kIsWeb) {
      try {
        final cache = await web.window.caches.open('model-cache').toDart;
        final modelPath = 'assets/models/${_selectedModel!.filename}';
        final response = await cache.match(modelPath.toJS).toDart;
        if (response != null) {
          // Model exists in cache, use cached path
          return modelPath;
        }
      } catch (e) {
        debugPrint('Error checking cache: $e');
      }
    }

    // Fall back to bundled asset path
    return 'assets/models/${_selectedModel!.filename}';
  }

  void selectModel(LLMModel model) {
    if (_selectedModel?.filename != model.filename) {
      _selectedModel = model;
      notifyListeners();
    }
  }

  Future<void> addModel(String modelPath) async {
    if (!kIsWeb) {
      throw UnsupportedError('Web-only implementation');
    }

    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final filename = modelPath.split('/').last;

      // Stream download for progress tracking
      final request = http.Request('GET', Uri.parse(modelPath));
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Failed to download model: ${streamedResponse.statusCode}',
        );
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      List<int> bytes = [];

      // Read response in chunks to track progress
      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          _downloadProgress = bytes.length / contentLength;
          notifyListeners();
        }
      }

      // Convert List<int> to Uint8List for ArrayBuffer/Blob creation
      final Uint8List downloadedData = Uint8List.fromList(bytes);

      // Create a web.Response object to store in the Cache API
      final web.Response cacheResponse = web.Response(
        downloadedData
            .toJS, // Convert Uint8List to JavaScript's JSAny for the body
        web.ResponseInit(status: 200, statusText: 'OK'),
      );

      // Store in Cache API
      final cache = await web.window.caches.open('model-cache').toDart;

      final cachePath = 'assets/models/$filename';

      // Create a web.Request object from the path for the key
      final web.Request cacheKeyRequest = web.Request(cachePath.toJS);

      // Use the web.Request object as the key and the cacheResponse as the value
      cache.put(cacheKeyRequest, cacheResponse);

      debugPrint('Model cached successfully: $cachePath');

      _downloadProgress = 1.0;
      notifyListeners();

      // Rescan to include the new model
      await rescanModels();
    } catch (e) {
      debugPrint('Error downloading/caching model: $e');
      _downloadProgress = 0.0;
      notifyListeners();
      rethrow;
    }
  }
}
