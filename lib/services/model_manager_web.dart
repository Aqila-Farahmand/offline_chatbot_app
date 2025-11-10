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

      // Get bundled model paths (include .litertlm for web)
      final modelAssetPaths = manifestMap.keys.where(
        (assetPath) =>
            assetPath.startsWith(modelPath) &&
            (assetPath.endsWith('.gguf') ||
                assetPath.endsWith('.task') ||
                assetPath.endsWith('.litertlm')),
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
              .where(
                (key) =>
                    key.endsWith('.gguf') ||
                    key.endsWith('.task') ||
                    key.endsWith('.litertlm'),
              )
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
            .replaceAll('.task', '')
            .replaceAll('.litertlm', '');
        final isTask =
            filename.endsWith('.task') || filename.endsWith('.litertlm');
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
              .replaceAll('.task', '')
              .replaceAll('.litertlm', '');
          final isTask =
              filename.endsWith('.task') || filename.endsWith('.litertlm');
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

      // Automatically select a compatible model for web platform
      if (_availableModels.isNotEmpty) {
        _selectedModel ??= _selectCompatibleModel() ?? _availableModels.first;
        debugPrint('Auto-selected model for web: ${_selectedModel!.filename}');
      } else {
        _selectedModel = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error scanning assets: $e');
      rethrow;
    }
  }

  /// Select a model compatible with web platform (.task, .litertlm formats)
  LLMModel? _selectCompatibleModel() {
    // Web requires .task or .litertlm models (MediaPipe/LiteRT formats)
    final compatibleModels = _availableModels
        .where(
          (model) =>
              model.filename.endsWith('.task') ||
              model.filename.endsWith('.litertlm'),
        )
        .toList();

    if (compatibleModels.isNotEmpty) {
      // Prefer downloaded/cached models over bundled
      final downloaded = compatibleModels
          .where(
            (model) =>
                model.isDownloaded && model.description.contains('Downloaded'),
          )
          .toList();
      if (downloaded.isNotEmpty) {
        return downloaded.first;
      }
      return compatibleModels.first;
    }

    // If no .task models, return null (will fallback to first model)
    return null;
  }

  Future<void> rescanModels() async {
    final previousModel = _selectedModel?.filename;
    await _scanBundledAssets();

    // If the previous model is no longer available or we didn't have one,
    // auto-select a compatible model
    if (_selectedModel == null ||
        !_availableModels.any((m) => m.filename == previousModel)) {
      _selectedModel =
          _selectCompatibleModel() ??
          (_availableModels.isNotEmpty ? _availableModels.first : null);
      if (_selectedModel != null) {
        debugPrint(
          'Auto-selected model after rescan: ${_selectedModel!.filename}',
        );
      }
      notifyListeners();
    }
  }

  Future<String?> getSelectedModelPath() async {
    if (_selectedModel == null) return null;

    // Check cache first for downloaded models (works offline)
    if (kIsWeb) {
      try {
        final cache = await web.window.caches.open('model-cache').toDart;
        final modelPath = '${AppPaths.modelPaths}${_selectedModel!.filename}';
        // Use Request object to match the cache key format used when storing
        final cacheKeyRequest = web.Request(modelPath.toJS);
        final response = await cache.match(cacheKeyRequest).toDart;
        if (response != null) {
          // Model exists in cache - can be used offline!
          debugPrint('Using cached model (offline-capable): $modelPath');
          return modelPath;
        } else {
          debugPrint('Model not in cache, will use bundled asset: $modelPath');
        }
      } catch (e) {
        debugPrint('Error checking cache (may be offline): $e');
        // Continue to fallback even if cache check fails (offline scenario)
      }
    }

    // Fall back to bundled asset path (works offline if bundled)
    return '${AppPaths.modelPaths}${_selectedModel!.filename}';
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

      final cachePath = '${AppPaths.modelPaths}$filename';

      // Create a web.Request object from the path for the key
      final web.Request cacheKeyRequest = web.Request(cachePath.toJS);

      // Use the web.Request object as the key and the cacheResponse as the value
      await cache.put(cacheKeyRequest, cacheResponse).toDart;

      debugPrint('Model cached successfully: $cachePath');

      _downloadProgress = 1.0;
      notifyListeners();

      // Rescan to include the new model
      await rescanModels();

      // Automatically select the newly downloaded model if it's compatible
      final newModel = _availableModels.firstWhere(
        (m) => m.filename == filename,
        orElse: () => _availableModels.first,
      );
      if (newModel.filename.endsWith('.task')) {
        selectModel(newModel);
        debugPrint(
          'Auto-selected newly downloaded model: ${newModel.filename}',
        );
      }
    } catch (e) {
      debugPrint('Error downloading/caching model: $e');
      _downloadProgress = 0.0;
      notifyListeners();
      rethrow;
    }
  }
}
