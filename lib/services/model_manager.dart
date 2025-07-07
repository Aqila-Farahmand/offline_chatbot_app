import 'dart:io';
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

      // Check for default model in assets and copy if no models exist
      final modelFiles = Directory(_modelsPath!)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.gguf'))
          .toList();

      print('Found ${modelFiles.length} existing model(s)');

      if (modelFiles.isEmpty) {
        print('No existing models found, attempting to copy default model...');
        try {
          // Copy default model from assets
          final defaultModelName = 'gemma3-1b.gguf';
          print('Loading default model from assets: $defaultModelName');

          final byteData = await rootBundle.load(
            'assets/models/$defaultModelName',
          );
          final buffer = byteData.buffer;
          final modelFile = File('$_modelsPath/$defaultModelName');

          print('Copying default model to: ${modelFile.path}');
          await modelFile.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          );
          print('Successfully copied default model');
        } catch (e) {
          print('Error copying default model: $e');
          throw Exception('Failed to copy default model: $e');
        }
      }

      // Scan for downloaded models
      await _scanDownloadedModels();
    } catch (e) {
      print('Error initializing ModelManager: $e');
      rethrow;
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

      // Select first available model if none selected
      if (_selectedModel == null && _availableModels.isNotEmpty) {
        _selectedModel = _availableModels.first;
        print('Selected model: ${_selectedModel!.filename}');
      } else if (_availableModels.isEmpty) {
        print('Warning: No models available after scan');
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
