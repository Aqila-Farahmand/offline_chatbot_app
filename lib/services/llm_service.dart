import 'dart:io';
import '../utils/bundle_utils.dart';
import 'model_manager.dart';

import 'mediapipe_android_service.dart';

class LLMService {
  static bool _isInitialized = false;
  static String? _modelPath;
  static String? _llamaCliPath;
  static final ModelManager _modelManager = ModelManager();
  
  static bool _isMediaPipe = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      print('LLM already initialized');
      return;
    }

    try {
      print('Initializing LLM service...');

      if (Platform.isAndroid) {
        // Initialize model manager and get model path
        await _modelManager.initialize();
        _modelPath = await _modelManager.getSelectedModelPath();

        // If a .task model exists in /data/local/tmp/llm, prefer it
        try {
          final tmpTaskDir = Directory('/data/local/tmp/llm');
          if (await tmpTaskDir.exists()) {
            final taskFiles = tmpTaskDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.task'))
                .toList();
            if (taskFiles.isNotEmpty) {
              _modelPath = taskFiles.first.path;
              print('Found external MediaPipe task model at: $_modelPath');
            }
          }
        } catch (_) {}

        if (_modelPath == null) {
          throw Exception('No model selected or found');
        }

        // Require MediaPipe on Android: ensure a .task model exists
        final modelFile = File(_modelPath!);
        final isTaskModel = _modelPath!.endsWith('.task');
        if (await modelFile.exists() && isTaskModel) {
          print('Initializing MediaPipe LLM service with model: $_modelPath');
          await MediapipeAndroidService.initialize(_modelPath!);
          _isMediaPipe = true;
          _isInitialized = true;
          print('MediaPipe LLM initialized successfully');
        } else {
          throw Exception('MediaPipe .task model not found. Please push a .task model to /data/local/tmp/llm or add one to assets/models/.');
        }
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
      rethrow;
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      throw Exception('LLM not initialized. Please initialize first.');
    }

    if (Platform.isAndroid) {
      try {
        if (!_isMediaPipe) {
          throw Exception('MediaPipe LLM not initialized');
        }
        print('Generating response using MediaPipe LLM...');
        return await MediapipeAndroidService.generate(prompt);
      } catch (e) {
        print('Error generating response on Android: $e');
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

  static void dispose() {
    if (Platform.isAndroid) {
      // Ensure MediaPipe is also disposed if used
      MediapipeAndroidService.dispose();
    }
    _isInitialized = false;
    _isMediaPipe = false;
    _modelPath = null;
    _llamaCliPath = null;
  }
}
