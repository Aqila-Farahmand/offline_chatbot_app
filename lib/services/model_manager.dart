import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/bundle_utils.dart';
import '../models/llm_model.dart';

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
      // Get models directory from BundleUtils
      _modelsPath = await BundleUtils.getModelsDirectory();
      print('Models directory initialized at: $_modelsPath');

      // Copy any .gguf models bundled in assets into the writable models
      // directory so that they can be listed and used like normal files.
      await _copyBundledModels();
      // Scan for available models after copying bundled ones
      await _scanDownloadedModels();
    } catch (e) {
      print('Error initializing ModelManager: $e');
      rethrow;
    }
  }

  /// Copy all .gguf files that are packaged under assets/models/ into the
  /// app's writable models directory. This ensures they are accessible via a
  /// regular file path for the llama runtime and appear in the model list.
  Future<void> _copyBundledModels() async {
    try {
      if (_modelsPath == null) {
        throw Exception('Models path not initialized');
      }

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      for (final assetPath in manifestMap.keys) {
        if (assetPath.startsWith('assets/models/') &&
            assetPath.endsWith('.gguf')) {
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
      // Log but do not fail initialisation – app can still run if copy fails.
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
          .where((file) => file.path.endsWith('.gguf'))
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

          _availableModels.add(
            LLMModel(
              name: filename.replaceAll('.gguf', ''),
              filename: filename,
              description:
                  'Local model (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
              contextSize: 2048,
              isDownloaded: true,
            ),
          );
        } catch (e) {
          print('Error processing model $filename: $e');
          // Continue with next model
          continue;
        }
      }

      // Ensure we always have a valid selected model.
      if (_availableModels.isEmpty) {
        // No models left – clear selection.
        _selectedModel = null;
        print('Warning: No models available after scan');
      } else {
        final stillExists =
            _selectedModel != null &&
            _availableModels.any((m) => m.filename == _selectedModel!.filename);

        if (!stillExists) {
          // Either nothing was selected before, or the previously selected
          // model is no longer present. Default to the first available model.
          _selectedModel = _availableModels.first;
          print('Selected model: ${_selectedModel!.filename}');
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error scanning models: $e');
      rethrow;
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
      if (!filename.endsWith('.gguf')) {
        throw Exception('Invalid model file format. Expected .gguf file');
      }

      if (_modelsPath == null) {
        throw Exception('Models path not initialized');
      }

      final destPath = '$_modelsPath/$filename';
      print('Copying model to: $destPath');

      // Copy model to models directory
      await file.copy(destPath);

      // Rescan models
      await _scanDownloadedModels();
    } catch (e) {
      print('Error adding model: $e');
      rethrow;
    }
  }
}
