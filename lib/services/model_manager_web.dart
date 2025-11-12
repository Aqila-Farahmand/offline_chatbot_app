import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/llm_model.dart';
import '../config/path_configs.dart';
import 'model_storage_web.dart';
import 'model_upload_web.dart';

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

      // Check storage for downloaded models
      List<String> cachedModelPaths = [];
      if (kIsWeb) {
        try {
          final storedModels = await ModelStorageWeb.listModels();
          cachedModelPaths = storedModels;
        } catch (e) {
          debugPrint('Error checking storage: $e');
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
        _selectedModel ??= _selectCompatibleModel();
        if (_selectedModel == null) {
          debugPrint(
            'Warning: No web-compatible model found. User must manually select a model.',
          );
        } else {
          debugPrint(
            'Auto-selected model for web: ${_selectedModel!.filename}',
          );
        }
      } else {
        _selectedModel = null;
        debugPrint('Warning: No models available');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error scanning assets: $e');
      rethrow;
    }
  }

  /// Select a model compatible with web platform (.task, .litertlm formats)
  /// Prioritizes web-specific models (with -web.task suffix) over Android models
  LLMModel? _selectCompatibleModel() {
    // Web requires .task or .litertlm models (MediaPipe/LiteRT formats)
    final compatibleModels = _availableModels
        .where(
          (model) =>
              model.filename.endsWith('.task') ||
              model.filename.endsWith('.litertlm'),
        )
        .toList();

    if (compatibleModels.isEmpty) {
      debugPrint(
        'Warning: No web-compatible models found (.task or .litertlm)',
      );
      return null;
    }

    // First priority: Web-specific models (with -web.task suffix)
    final webSpecificModels = compatibleModels
        .where(
          (model) =>
              model.filename.contains('-web.task') ||
              model.filename.endsWith('-web.litertlm'),
        )
        .toList();

    if (webSpecificModels.isNotEmpty) {
      // Prefer downloaded/cached web models over bundled
      final downloadedWeb = webSpecificModels
          .where(
            (model) =>
                model.isDownloaded && model.description.contains('Downloaded'),
          )
          .toList();
      if (downloadedWeb.isNotEmpty) {
        debugPrint(
          'Selected web-specific downloaded model: ${downloadedWeb.first.filename}',
        );
        return downloadedWeb.first;
      }
      debugPrint(
        'Selected web-specific bundled model: ${webSpecificModels.first.filename}',
      );
      return webSpecificModels.first;
    }

    // Second priority: Other .task/.litertlm models (but warn if they might be Android models)
    // Prefer downloaded/cached models over bundled
    final downloaded = compatibleModels
        .where(
          (model) =>
              model.isDownloaded && model.description.contains('Downloaded'),
        )
        .toList();
    if (downloaded.isNotEmpty) {
      debugPrint(
        'Warning: No web-specific models found. Using downloaded model: ${downloaded.first.filename}',
      );
      return downloaded.first;
    }

    // Last resort: any compatible model (but warn)
    debugPrint(
      'Warning: No web-specific models found. Using bundled model: ${compatibleModels.first.filename}',
    );
    debugPrint(
      'Note: This model may not be optimized for web. Consider using a model with -web.task suffix.',
    );
    return compatibleModels.first;
  }

  Future<void> rescanModels() async {
    final previousModel = _selectedModel?.filename;
    await _scanBundledAssets();

    // If the previous model is no longer available or we didn't have one,
    // auto-select a compatible model (prioritizing web-specific models)
    if (_selectedModel == null ||
        !_availableModels.any((m) => m.filename == previousModel)) {
      _selectedModel = _selectCompatibleModel();
      if (_selectedModel != null) {
        debugPrint(
          'Auto-selected model after rescan: ${_selectedModel!.filename}',
        );
      } else {
        debugPrint(
          'Warning: No web-compatible model found after rescan. User must manually select.',
        );
      }
      notifyListeners();
    }
  }

  Future<String?> getSelectedModelPath() async {
    if (_selectedModel == null) return null;

    // Check storage first for downloaded models (works offline)
    if (kIsWeb) {
      try {
        final exists = await ModelStorageWeb.hasModel(_selectedModel!.filename);
        if (exists) {
          // Model exists in storage - can be used offline!
          final modelPath = ModelStorageWeb.getModelPath(
            _selectedModel!.filename,
          );
          debugPrint('Using stored model (offline-capable): $modelPath');
          return modelPath;
        } else {
          debugPrint(
            'Model not in storage, will use bundled asset: ${_selectedModel!.filename}',
          );
        }
      } catch (e) {
        debugPrint('Error checking storage (may be offline): $e');
        // Continue to fallback even if storage check fails (offline scenario)
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

  /// Upload a model file manually (for web users who download externally)
  Future<void> uploadModel({
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    if (!kIsWeb) {
      onError('Upload is only available on web platform');
      return;
    }

    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final filename = await ModelUploadWeb.uploadModel(
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      if (filename == null) {
        // User cancelled
        _downloadProgress = 0.0;
        notifyListeners();
        return;
      }

      _downloadProgress = 1.0;
      notifyListeners();

      // Rescan to include the new model
      await rescanModels();

      // Automatically select the newly uploaded model if it's web-compatible
      final newModel = _availableModels.firstWhere(
        (m) => m.filename == filename,
        orElse: () => _availableModels.first,
      );
      // Only auto-select if it's a web-compatible format
      if (newModel.filename.endsWith('.task') ||
          newModel.filename.endsWith('.litertlm')) {
        // Prefer web-specific models, but allow any compatible model
        if (_selectedModel == null ||
            newModel.filename.contains('-web.task') ||
            newModel.filename.endsWith('-web.litertlm')) {
          selectModel(newModel);
          debugPrint(
            'Auto-selected newly uploaded model: ${newModel.filename}',
          );
        } else {
          debugPrint(
            'Uploaded model ${newModel.filename} is available but not auto-selected. '
            'Current selection: ${_selectedModel?.filename}',
          );
        }
      }

      onComplete();
    } catch (e) {
      debugPrint('Error uploading model: $e');
      _downloadProgress = 0.0;
      notifyListeners();
      onError('Upload failed: $e');
    }
  }
}
