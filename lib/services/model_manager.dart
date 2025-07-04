import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/llm_model.dart';

class ModelManager extends ChangeNotifier {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  List<LLMModel> _availableModels = [];
  LLMModel? _selectedModel;
  final String _modelsDir = 'models';

  List<LLMModel> get availableModels => _availableModels;
  LLMModel? get selectedModel => _selectedModel;

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsPath = '${appDir.path}/$_modelsDir';

    // Create models directory if it doesn't exist
    final modelsDirExists = await Directory(modelsPath).exists();
    if (!modelsDirExists) {
      await Directory(modelsPath).create(recursive: true);
    }

    // Check for default model in assets and copy if no models exist
    final modelFiles = Directory(modelsPath)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.gguf'))
        .toList();

    if (modelFiles.isEmpty) {
      try {
        // Copy default model from assets
        final byteData = await rootBundle.load(
          'assets/models/gemma-2b-q4.gguf',
        );
        final buffer = byteData.buffer;
        await File('$modelsPath/gemma-2b-q4.gguf').writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
        print('Copied default model to: $modelsPath/gemma-2b-q4.gguf');
      } catch (e) {
        print('No default model available in assets: $e');
      }
    }

    // Scan for downloaded models
    await _scanDownloadedModels();
  }

  Future<void> _scanDownloadedModels() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsPath = '${appDir.path}/$_modelsDir';

    final modelFiles = Directory(modelsPath)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.gguf'))
        .toList();

    _availableModels = modelFiles.map((file) {
      final filename = file.path.split('/').last;
      return LLMModel(
        name: filename.replaceAll('.gguf', ''),
        filename: filename,
        description: 'Local model',
        contextSize: 2048,
        isDownloaded: true,
      );
    }).toList();

    // Select first available model if none selected
    if (_selectedModel == null && _availableModels.isNotEmpty) {
      _selectedModel = _availableModels.first;
    }

    notifyListeners();
  }

  Future<String?> getSelectedModelPath() async {
    if (_selectedModel == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$_modelsDir/${_selectedModel!.filename}';
  }

  void selectModel(LLMModel model) {
    if (_selectedModel?.filename != model.filename) {
      _selectedModel = model;
      notifyListeners();
    }
  }

  Future<void> addModel(String modelPath) async {
    final file = File(modelPath);
    if (!await file.exists()) return;

    final filename = file.path.split('/').last;
    if (!filename.endsWith('.gguf')) return;

    final appDir = await getApplicationDocumentsDirectory();
    final destPath = '${appDir.path}/$_modelsDir/$filename';

    // Copy model to models directory
    await file.copy(destPath);

    // Rescan models
    await _scanDownloadedModels();
  }
}
