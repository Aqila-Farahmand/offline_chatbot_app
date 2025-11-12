import 'dart:io';
import '../utils/bundle_utils.dart';
import 'model_manager.dart';
import '../config/prompt_configs.dart';
import '../config/llm_config.dart';
import '../utils/token_estimator.dart';
import 'mediapipe_android_service.dart';

class LLMService {
  static bool _isInitialized = false;
  static String? _modelPath;
  static String? _llamaCliPath;
  static final ModelManager _modelManager = ModelManager();
  static bool _isMediaPipe = false;

  // Last error message (for UI/debugging)
  static String? lastError;

  // --- Add a getter to access the current prompt label if needed ---
  static String get currentPromptLabel => kMedicalSafetyPromptLabel;

  /// Public getter for last error for debugging.
  static String? get lastErrorMessage => lastError;

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
          throw Exception(
            'MediaPipe .task model not found. Please download a .task model to /data/local/tmp/llm or add one to assets/models/.',
          );
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
      lastError = e.toString();
      print('Error initializing LLM: $e');
      _isInitialized = false;
      _modelPath = null;
      _llamaCliPath = null;
      rethrow;
    }
  }

  // Chat history management (similar to web service)
  static final List<Map<String, String>> _chatHistory = [];

  /// Smart history truncation with token awareness (similar to web)
  static void _truncateHistoryIfNeeded(String newQuery) {
    // Hard limit: never exceed max history turns
    if (_chatHistory.length > LLMConfig.maxHistoryTurns) {
      final removed = _chatHistory.length - LLMConfig.maxHistoryTurns;
      _chatHistory.removeRange(0, removed);
      print('Trimmed chat history to ${LLMConfig.maxHistoryTurns} turns.');
    }

    // Estimate tokens and truncate if needed
    final queryTokens = TokenEstimator.estimateTokens(newQuery);
    final systemTokens = TokenEstimator.estimateTokens(kMedicalSafetyPrompt);
    final availableForHistory = LLMConfig.calculateAvailableHistoryTokens(
      2048, // Default context size for IO (can be made configurable)
      queryTokens + systemTokens,
    );

    int currentHistoryTokens = 0;
    for (final entry in _chatHistory) {
      currentHistoryTokens += TokenEstimator.estimateHistoryEntryTokens(entry);
    }

    if (currentHistoryTokens > availableForHistory) {
      // Progressive truncation
      int targetTurns = LLMConfig.preferredHistoryTurns;
      while (targetTurns >= LLMConfig.minHistoryTurns) {
        int testTokens = 0;
        final startIndex = _chatHistory.length > targetTurns
            ? _chatHistory.length - targetTurns
            : 0;

        for (int i = startIndex; i < _chatHistory.length; i++) {
          testTokens += TokenEstimator.estimateHistoryEntryTokens(
            _chatHistory[i],
          );
        }

        if (testTokens <= availableForHistory) {
          if (_chatHistory.length > targetTurns) {
            _chatHistory.removeRange(0, _chatHistory.length - targetTurns);
            print(
              'Progressive truncation: Reduced history to $targetTurns turns.',
            );
          }
          return;
        }
        targetTurns--;
      }

      // Last resort: keep minimum history
      if (_chatHistory.length > LLMConfig.minHistoryTurns) {
        _chatHistory.removeRange(
          0,
          _chatHistory.length - LLMConfig.minHistoryTurns,
        );
        print(
          'Minimum truncation: Reduced history to ${LLMConfig.minHistoryTurns} turns.',
        );
      }
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      lastError = 'LLM not initialized. Please initialize first.';
      throw Exception(lastError);
    }

    // Proactively truncate history before generating
    _truncateHistoryIfNeeded(prompt);

    // Format prompt with history (simple format for IO)
    String formattedPrompt = prompt;
    if (_chatHistory.isNotEmpty) {
      final StringBuffer sb = StringBuffer();
      for (final entry in _chatHistory) {
        sb.writeln('User: ${entry['user']}');
        sb.writeln('Assistant: ${entry['assistant']}');
        sb.writeln();
      }
      sb.writeln('User: $prompt');
      sb.writeln('Assistant:');
      formattedPrompt = sb.toString();
    } else {
      formattedPrompt = '$kMedicalSafetyPrompt\n\nUser: $prompt\nAssistant:';
    }

    if (Platform.isAndroid) {
      try {
        if (!_isMediaPipe) {
          throw Exception('MediaPipe LLM not initialized');
        }
        print('Generating response using MediaPipe LLM...');
        final response = await MediapipeAndroidService.generate(
          formattedPrompt,
        );
        // Update history
        _chatHistory.add({'user': prompt, 'assistant': response});
        return response;
      } catch (e) {
        lastError = e.toString();
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

        // Create a temporary file for the prompt (already formatted with history)
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
            '1280',
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

        final responseText = result.stdout.toString();
        final rawResponse = responseText.split('Assistant:').last.trim();
        String response = rawResponse;
        final prefixPattern = RegExp(
          r'^(<\|assistant\|>|assistant\s*(<[^>]*>)?\s*:?|model\s*(<[^>]*>)?\s*:?)',
          caseSensitive: false,
        );
        while (prefixPattern.hasMatch(response)) {
          response = response.replaceFirst(prefixPattern, '').trim();
        }

        await promptFile.delete();

        // Update history
        _chatHistory.add({'user': prompt, 'assistant': response});

        return response;
      } catch (e) {
        lastError = e.toString();
        print('Error generating response with macOS executable: $e');
        rethrow;
      }
    }
  }

  static void dispose() {
    if (Platform.isAndroid) {
      MediapipeAndroidService.dispose();
    }
    _isInitialized = false;
    _isMediaPipe = false;
    _modelPath = null;
    _llamaCliPath = null;
    _chatHistory.clear();
    lastError = null;
  }

  /// Clears the chat history
  static void clearHistory() {
    _chatHistory.clear();
    print('Chat history cleared.');
  }
}
