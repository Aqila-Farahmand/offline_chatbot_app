import 'dart:io';
import '../utils/bundle_utils.dart';
import 'model_manager.dart';
import '../constants/prompts.dart';

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

  static Future<String> generateResponse(String prompt, {List<Map<String, String>>? history}) async {
    if (!_isInitialized) {
      throw Exception('LLM not initialized. Please initialize first.');
    }

    // Prepend the MedicoAI safety system prompt for all platforms
    // Unified conversation format across all platforms: User/Assistant
    const String userLabel = 'User';
    const String assistantLabel = 'Assistant';

    final buffer = StringBuffer();
    // Include system guidance
    buffer.writeln(kMedicoAISystemPrompt.trim());
    buffer.writeln('Respond in plain text. Do not use JSON, code blocks, or tool calls.');
    if (history != null && history.isNotEmpty) {
      for (final turn in history) {
        final type = turn['type'];
        final msg = (turn['message'] ?? '').trim();
        if (msg.isEmpty) continue;
        if (type == 'user') {
          buffer.writeln('$userLabel: ' + msg);
        } else if (type == 'bot') {
          buffer.writeln('$assistantLabel: ' + msg);
        }
      }
    }
    buffer.writeln('$userLabel: ' + prompt);
    buffer.write('$assistantLabel:');
    final combinedPrompt = buffer.toString();
    final chatFormattedPrompt = combinedPrompt;

    if (Platform.isAndroid) {
      try {
        if (!_isMediaPipe) {
          throw Exception('MediaPipe LLM not initialized');
        }
        print('Generating response using MediaPipe LLM...');
        final raw = await MediapipeAndroidService.generate(chatFormattedPrompt);
        final section = raw.contains(assistantLabel + ':')
            ? raw.split(assistantLabel + ':').last
            : raw;
        return _cleanResponse(section);
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

        // Format the prompt with system instruction for medical context
        final formattedPrompt = chatFormattedPrompt;

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
            '0.65',
            '--top_p',
            '0.9',
            '--threads',
            '${Platform.numberOfProcessors - 1}',
            '--ctx_size',
            '2048',
            '-n',
            '512',
            // Stop when the model tries to switch roles or emits common end tokens
            '-r',
            'User:',
            '-r',
            'Assistant:',
            '-r',
            'EOF',
            '-r',
            'EOF by user',
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
        final rawSection = responseText.contains(assistantLabel + ':')
            ? responseText.split(assistantLabel + ':').last
            : responseText;
        final response = _cleanResponse(rawSection);

        // Clean up the temporary file
        await promptFile.delete();

        return response;
      } catch (e) {
        print('Error generating response with macOS executable: $e');
        rethrow;
      }
    }
  }

  static String _cleanResponse(String text) {
    final original = text.trim();
    String response = original;

    // Remove common assistant prefixes repeatedly
    final prefixPattern = RegExp(
      r'^(<\|assistant\|>|assistant\s*(<[^>]*>)?\s*:?|model\s*(<[^>]*>)?\s*:?)',
      caseSensitive: false,
    );
    while (prefixPattern.hasMatch(response)) {
      response = response.replaceFirst(prefixPattern, '').trim();
    }

    // Remove all code fences and markdown headings inline
    response = response.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
    response = response.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');

    // Remove tool/JSON artifacts
    if (RegExp(r'^\s*\[\s*\{').hasMatch(response)) {
      // If starts with JSON array/object, drop it and keep nothing
      response = '';
    }

    // Remove known placeholders
    response = response.replaceAll('[bullet list]', '').replaceAll('General non-diagnostic information.', '');

    // Truncate at trailing role switches or EOF markers
    final stopMarkers = <String>['\nUser:', '\nAssistant:', 'User:', 'Assistant:', 'EOF by user', 'EOF', '<eos>', '</s>'];
    int cut = response.length;
    for (final m in stopMarkers) {
      final i = response.indexOf(m);
      if (i != -1 && i < cut) cut = i;
    }
    response = response.substring(0, cut);

    // Strip blockquote markers ('>') at line starts
    response = response
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*>\s*'), ''))
        .join('\n');

    response = response.trim();

    // Fallback: if cleaning resulted in empty output, return original
    if (response.isEmpty) {
      response = original;
    }
    if (response.isEmpty) {
      response = 'I could not generate a response. Could you clarify your question?';
    }
    return response;
  }

  // Test method for debugging (removed since we're using ONNX now)
  // static Future<String> testAndroidNativeLibrary() async {
  //   if (Platform.isAndroid && _androidService != null) {
  //     return await _androidService!.testNativeLibrary();
  //   }
  //   return 'Not available on this platform';
  // }

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
