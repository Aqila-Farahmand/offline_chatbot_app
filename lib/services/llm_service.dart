import 'dart:io';
import '../utils/bundle_utils.dart';
import 'model_manager.dart';

class LLMService {
  static bool _isInitialized = false;
  static String? _modelPath;
  static String? _llamaCliPath;
  static final ModelManager _modelManager = ModelManager();

  static Future<void> initialize() async {
    if (_isInitialized) {
      print('LLM already initialized');
      return;
    }

    try {
      print('Initializing LLM service...');

      // Initialize llama-cli path
      _llamaCliPath = await BundleUtils.getLlamaCli();
      print('Llama CLI initialized at: $_llamaCliPath');

      // Verify llama-cli is executable
      final llamaCli = File(_llamaCliPath!);
      if (!await llamaCli.exists()) {
        throw Exception('llama-cli not found at $_llamaCliPath');
      }

      // Initialize model manager and get model path
      await _modelManager.initialize();
      _modelPath = await _modelManager.getSelectedModelPath();

      if (_modelPath == null) {
        throw Exception('No model selected');
      }

      // Verify model file exists
      final modelFile = File(_modelPath!);
      if (!await modelFile.exists()) {
        throw Exception('Model file not found at $_modelPath');
      }

      _isInitialized = true;
      print('LLM initialized successfully');
      print('Using model: $_modelPath');
    } catch (e) {
      print('Error initializing LLM: $e');
      _isInitialized = false;
      _modelPath = null;
      _llamaCliPath = null;
      rethrow;
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      throw Exception('LLM not initialized. Please initialize first.');
    }

    if (_modelPath == null || _llamaCliPath == null) {
      throw Exception('Model path or llama-cli path is null');
    }

    try {
      print('Generating response...');

      // Get temp directory for prompt file
      final tempDir = await BundleUtils.getTempDirectory();
      print('Using temp directory: $tempDir');

      // Format the prompt for medical context
      final formattedPrompt =
          '''
System: You are a medical AI assistant. Provide accurate, helpful medical information while clearly stating that you are not a substitute for professional medical advice.

User: $prompt
Assistant:''';

      // Create a temporary file for the prompt
      final promptFile = File('$tempDir/prompt.txt');
      await promptFile.writeAsString(formattedPrompt);
      print('Created prompt file at: ${promptFile.path}');

      print('Running llama with model: $_modelPath');

      // Run llama.cpp with the model and prompt
      final llamaDir = File(_llamaCliPath!).parent.path; // .../llama
      final libDir = '${Directory(llamaDir).parent.path}/lib';

      final result = await Process.run(
        _llamaCliPath!,
        [
          '-m',
          _modelPath!,
          '-f',
          promptFile.path,
          '--temp',
          '0.7',
          '--top_p',
          '0.9',
          '--threads',
          '${Platform.numberOfProcessors - 1}',
          '--ctx_size',
          '2048',
          '-n',
          '512',
        ],
        environment: {
          'DYLD_LIBRARY_PATH':
              '$libDir:${Platform.environment['DYLD_LIBRARY_PATH'] ?? ''}',
        },
      );

      if (result.exitCode != 0) {
        throw Exception(
          'llama-cli exited with code ${result.exitCode}: ${result.stderr}',
        );
      }

      // Wrap result in Shell-like Output
      final responseText = result.stdout.toString();
      final response = responseText.split('Assistant:').last.trim();

      // Clean up the temporary file
      await promptFile.delete();
      print('Cleaned up prompt file');

      print('Successfully generated response');
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
