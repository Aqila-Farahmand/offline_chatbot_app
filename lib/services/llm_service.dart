import 'dart:io';
import '../utils/bundle_utils.dart';
import 'model_manager.dart';

// Import Android-specific service if on Android
import 'android_llm_service.dart' if (dart.library.html) 'dummy_android_service.dart';

class LLMService {
  static bool _isInitialized = false;
  static String? _modelPath;
  static String? _llamaCliPath;
  static final ModelManager _modelManager = ModelManager();
  
  // Android-specific service instance
  static AndroidLLMService? _androidService;

  static Future<void> initialize() async {
    if (_isInitialized) {
      print('LLM already initialized');
      return;
    }

    try {
      print('Initializing LLM service...');

      if (Platform.isAndroid) {
        // Use Android native library approach
        print('Initializing Android LLM service...');
        _androidService = AndroidLLMService();
        await _androidService!.initialize();
        
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

        // Initialize the native library with the model
        final success = await _androidService!.initLlama(_modelPath!);
        if (!success) {
          throw Exception('Failed to initialize llama native library');
        }

        _isInitialized = true;
        print('Android LLM initialized successfully');
        print('Using model: $_modelPath');
      } else {
        // Use macOS executable approach
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
        print('macOS LLM initialized successfully');
        print('Using model: $_modelPath');
      }
    } catch (e) {
      print('Error initializing LLM: $e');
      _isInitialized = false;
      _modelPath = null;
      _llamaCliPath = null;
      _androidService = null;
      rethrow;
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      throw Exception('LLM not initialized. Please initialize first.');
    }

    if (Platform.isAndroid) {
      // Use Android native library approach
      if (_androidService == null) {
        throw Exception('Android LLM service not initialized');
      }

      try {
        print('Generating response using Android native library...');
        
        // Format the prompt for medical context
        final formattedPrompt = 'User: $prompt\nAssistant:';

        final response = await _androidService!.generateText(formattedPrompt);
        print('Successfully generated response using Android native library');
        return response;
      } catch (e) {
        print('Error generating response with Android native library: $e');
        rethrow;
      }
    } else {
      // Use macOS executable approach
      if (_modelPath == null || _llamaCliPath == null) {
        throw Exception('Model path or llama-cli path is null');
      }

      try {
        print('Generating response using macOS executable...');

        // Get temp directory for prompt file
        final tempDir = await BundleUtils.getTempDirectory();
        print('Using temp directory: $tempDir');

        // Format the prompt for medical context
        final formattedPrompt = 'User: $prompt\nAssistant:';

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
        final rawResponse = responseText.split('Assistant:').last.trim();
        // Remove any leading '<|assistant|>', 'Assistant', 'Assistant:', 'Assistant <...>', 'model', 'model:', 'model <...>', or similar (case-insensitive, repeated)
        String response = rawResponse;
        final prefixPattern = RegExp(
          r'^(<\|assistant\|>|assistant\s*(<[^>]*>)?\s*:?|model\s*(<[^>]*>)?\s*:?)',
          caseSensitive: false,
        );
        while (prefixPattern.hasMatch(response)) {
          response = response.replaceFirst(prefixPattern, '').trim();
        }

        // Clean up the temporary file
        await promptFile.delete();

        return response;
      } catch (e) {
        print('Error generating response with macOS executable: $e');
        rethrow;
      }
    }
  }

  // Test function for Android native library
  static Future<String> testAndroidNativeLibrary() async {
    if (!Platform.isAndroid) {
      return "Test only available on Android";
    }

    if (!_isInitialized || _androidService == null) {
      return "Android LLM service not initialized";
    }

    try {
      print('Testing Android native library...');
      final result = await _androidService!.testNativeLibrary();
      print('Test result: $result');
      return result;
    } catch (e) {
      print('Test failed: $e');
      return "Test failed: $e";
    }
  }

  static void dispose() {
    if (Platform.isAndroid && _androidService != null) {
      _androidService!.freeLlama();
      _androidService = null;
    }
    _modelPath = null;
    _llamaCliPath = null;
    _isInitialized = false;
  }
}
