import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/llm_model.dart';

/// Web-safe ModelManager: lists bundled assets under assets/models and allows
/// selecting a model. No filesystem writes or downloads.
class ModelManager extends ChangeNotifier {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  List<LLMModel> _availableModels = [];
  LLMModel? _selectedModel;

  List<LLMModel> get availableModels => _availableModels;
  LLMModel? get selectedModel => _selectedModel;

  Future<void> initialize() async {
    try {
      await _scanBundledAssets();
    } catch (e) {
      print('Error initializing ModelManager (web): $e');
      rethrow;
    }
  }

  Future<void> _scanBundledAssets() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      final modelAssetPaths = manifestMap.keys.where(
        (assetPath) =>
            assetPath.startsWith('assets/models/') &&
            (assetPath.endsWith('.gguf') || assetPath.endsWith('.task')),
      );

      _availableModels = [];
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

      if (_availableModels.isNotEmpty) {
        _selectedModel ??= _availableModels.first;
      } else {
        _selectedModel = null;
      }

      notifyListeners();
    } catch (e) {
      print('Error scanning bundled assets (web): $e');
      rethrow;
    }
  }

  Future<void> rescanModels() async {
    await _scanBundledAssets();
  }

  /// On web, return the asset path to the selected model, e.g. assets/models/foo.gguf
  Future<String?> getSelectedModelPath() async {
    if (_selectedModel == null) return null;
    return 'assets/models/${_selectedModel!.filename}';
  }

  void selectModel(LLMModel model) {
    if (_selectedModel?.filename != model.filename) {
      _selectedModel = model;
      notifyListeners();
    }
  }

  Future<void> addModel(String modelPath) async {
    throw UnsupportedError('Adding models is not supported on web');
  }
}
