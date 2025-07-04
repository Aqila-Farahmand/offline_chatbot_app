import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import '../utils/bundle_utils.dart';
import 'model_manager.dart';

class LLMService {
  static bool _isInitialized = false;
  static String? _modelPath;
  static String? _llamaCliPath;
  static final ModelManager _modelManager = ModelManager();

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize llama-cli path
      _llamaCliPath = await BundleUtils.getLlamaCli();
      print('Llama CLI initialized at: $_llamaCliPath');

      // Initialize model manager and get model path
      await _modelManager.initialize();
      _modelPath = await _modelManager.getSelectedModelPath();

      if (_modelPath == null) {
        throw Exception('No model selected');
      }

      _isInitialized = true;
      print('LLM initialized successfully at: $_modelPath');
    } catch (e) {
      print('Error initializing LLM: $e');
      rethrow;
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized || _modelPath == null || _llamaCliPath == null) {
      throw Exception('LLM not initialized');
    }

    try {
      // Get temp directory for prompt file
      final tempDir = await BundleUtils.getTempDirectory();

      // Format the prompt for medical context
      final formattedPrompt =
          '''
System: You are a medical AI assistant. Provide accurate, helpful medical information while clearly stating that you are not a substitute for professional medical advice.

User: $prompt
Assistant:''';

      // Create a temporary file for the prompt
      final promptFile = File('$tempDir/prompt.txt');
      await promptFile.writeAsString(formattedPrompt);

      print('Running llama with model: $_modelPath');
      print('Prompt file location: ${promptFile.path}');

      // Run llama.cpp with the model and prompt
      final shell = Shell();
      final result = await shell.run('''
        "$_llamaCliPath" -m "$_modelPath" \\
        -f "${promptFile.path}" \\
        --temp 0.7 \\
        --top_p 0.9 \\
        --threads ${Platform.numberOfProcessors - 1} \\
        --ctx_size 2048 \\
        --max-tokens 512
      ''');

      // Clean up the temporary file
      await promptFile.delete();

      // Process and return the response
      final response = result.outText.split('Assistant:').last.trim();
      return response;
    } catch (e) {
      print('Error generating response: $e');
      rethrow;
    }
  }

  static void dispose() {
    _modelPath = null;
    _llamaCliPath = null;
    _isInitialized = false;
  }
}
