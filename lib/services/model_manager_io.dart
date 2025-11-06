import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/bundle_utils.dart';
import '../models/llm_model.dart';
import '../config/path_configs.dart';

class ModelManager extends ChangeNotifier {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  List<LLMModel> _availableModels = [];
  LLMModel? _selectedModel;
  String? _modelsPath;

  List<LLMModel> get availableModels => _availableModels;
  LLMModel? get selectedModel => _selectedModel;

  Future<void> initialize() async {
    try {
      _modelsPath = await BundleUtils.getModelsDirectory();
      print('Models directory initialized at: $_modelsPath');

      await _copyBundledModels();
      await _scanDownloadedModels();
    } catch (e) {
      print('Error initializing ModelManager: $e');
      rethrow;
    }
  }

  Future<void> _copyBundledModels() async {
    try {
      if (_modelsPath == null) {
        throw Exception('Models path not initialized');
      }

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      for (final assetPath in manifestMap.keys) {
        final isModelAsset =
            assetPath.startsWith(AppPaths.modelPaths) &&
            (assetPath.endsWith('.gguf') || assetPath.endsWith('.task'));
        if (isModelAsset) {
          final filename = assetPath.split('/').last;
          final destPath = '$_modelsPath/$filename';
          final destFile = File(destPath);

          if (!await destFile.exists()) {
            print('Copying bundled model $filename to writable directory...');
            final byteData = await rootBundle.load(assetPath);
            final buffer = byteData.buffer;
            await destFile.writeAsBytes(
              buffer.asUint8List(
                byteData.offsetInBytes,
                byteData.lengthInBytes,
              ),
            );
            print('Copied $filename');
          }
        }
      }
    } catch (e) {
      print('Error copying bundled models: $e');
    }
  }

  Future<void> _scanDownloadedModels() async {
    if (_modelsPath == null) {
      throw Exception('Models path not initialized');
    }

    try {
      print('Scanning for models in: $_modelsPath');

      final modelFiles = Directory(_modelsPath!)
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.gguf') || file.path.endsWith('.task'),
          )
          .toList();

      print('Found ${modelFiles.length} model(s)');

      _availableModels = [];
      for (var file in modelFiles) {
        final filename = file.path.split('/').last;
        print('Processing model: $filename');

        try {
          final fileSize = await file.length();
          print(
            'Model size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
          );

          final modelName = filename
              .replaceAll('.gguf', '')
              .replaceAll('.task', '');
          final isTask = filename.endsWith('.task');
          _availableModels.add(
            LLMModel(
              name: modelName,
              filename: filename,
              description: isTask
                  ? 'MediaPipe task model (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)'
                  : 'Local model (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
              contextSize: 2048,
              isDownloaded: true,
            ),
          );
        } catch (e) {
          print('Error processing model $filename: $e');
          continue;
        }
      }

      if (_availableModels.isEmpty) {
        _selectedModel = null;
        print('Warning: No models available after scan');
      } else {
        final stillExists =
            _selectedModel != null &&
            _availableModels.any((m) => m.filename == _selectedModel!.filename);

        if (!stillExists) {
          // Automatically select a compatible model for the platform
          _selectedModel = _selectCompatibleModel() ?? _availableModels.first;
          print('Auto-selected model: ${_selectedModel!.filename}');
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error scanning models: $e');
      rethrow;
    }
  }

  /// Select a model compatible with the current platform
  LLMModel? _selectCompatibleModel() {
    if (Platform.isAndroid) {
      // Android requires .task models (MediaPipe format)
      final compatibleModels = _availableModels
          .where((model) => model.filename.endsWith('.task'))
          .toList();

      if (compatibleModels.isNotEmpty) {
        print(
          'Found ${compatibleModels.length} Android-compatible .task model(s)',
        );
        return compatibleModels.first;
      }
      print('Warning: No .task models found for Android platform');
      return null;
    } else {
      // Desktop platforms (macOS, Windows, Linux) require .gguf models
      final compatibleModels = _availableModels
          .where((model) => model.filename.endsWith('.gguf'))
          .toList();

      if (compatibleModels.isNotEmpty) {
        print(
          'Found ${compatibleModels.length} desktop-compatible .gguf model(s)',
        );
        return compatibleModels.first;
      }
      print('Warning: No .gguf models found for desktop platform');
      return null;
    }
  }

  Future<void> rescanModels() async {
    final previousModel = _selectedModel?.filename;
    await _scanDownloadedModels();

    // If the previous model is no longer available or we didn't have one,
    // auto-select a compatible model
    if (_selectedModel == null ||
        !_availableModels.any((m) => m.filename == previousModel)) {
      _selectedModel = _selectCompatibleModel();
      if (_selectedModel == null && _availableModels.isNotEmpty) {
        _selectedModel = _availableModels.first;
      }
      if (_selectedModel != null) {
        print('Auto-selected model after rescan: ${_selectedModel!.filename}');
      }
      notifyListeners();
    }
  }

  Future<String?> getSelectedModelPath() async {
    if (_selectedModel == null || _modelsPath == null) return null;
    final modelPath = '$_modelsPath/${_selectedModel!.filename}';
    print('Selected model path: $modelPath');
    return modelPath;
  }

  void selectModel(LLMModel model) {
    if (_selectedModel?.filename != model.filename) {
      _selectedModel = model;
      print('Model selected: ${model.filename}');
      notifyListeners();
    }
  }

  Future<void> addModel(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        throw Exception('Model file does not exist: $modelPath');
      }

      final filename = file.path.split('/').last;
      final isValid = filename.endsWith('.gguf') || filename.endsWith('.task');
      if (!isValid) {
        throw Exception(
          'Invalid model file format. Expected .gguf or .task file',
        );
      }

      if (_modelsPath == null) {
        throw Exception('Models path not initialized');
      }

      final destPath = '$_modelsPath/$filename';
      print('Copying model to: $destPath');

      await file.copy(destPath);

      await _scanDownloadedModels();
    } catch (e) {
      print('Error adding model: $e');
      rethrow;
    }
  }
}
