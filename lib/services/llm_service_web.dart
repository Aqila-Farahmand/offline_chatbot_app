@JS()
library;

// Web implementation using JS bridge defined in web/mediapipe_text.js
import 'dart:async';
import 'dart:js_interop';
import '../config/path_configs.dart';
import 'model_manager.dart';
import '../config/prompt_configs.dart';
import 'package:flutter/foundation.dart';

@JS('MediapipeGenai')
external MediapipeGenai? get _mediapipeGenai;

@JS()
extension type MediapipeGenai(JSObject o) implements JSObject {
  external JSPromise init(InitOptions options);
  external JSPromise generate(String prompt);
  external void dispose();
}

@JS()
extension type InitOptions._(JSObject o) implements JSObject {
  external factory InitOptions({
    String modelAssetPath,
    String tasksModulePath,
    String wasmBasePath,
    bool cpuOnly,
    int? maxTokens,
  });
}

class LLMService {
  static bool _isInitialized = false;
  static final ModelManager _modelManager = ModelManager();
  static String? _modelAssetPath = AppPaths.gemma3WebModel;
  // allow forcing CPU-only initialization
  static bool preferCpuOnly = false;
  // max tokens configuration (default to 1280 for web)
  static int maxTokens = 1280;

  // Last error message (for UI/debugging)
  static String? lastError;

  static void setCpuOnly(bool value) {
    preferCpuOnly = value;
    if (kDebugMode) print('LLMService: setCpuOnly=$value');
  }

  static void setMaxTokens(int value) {
    maxTokens = value;
    if (kDebugMode) print('LLMService: setMaxTokens=$value');
  }

  /// Public getter to allow UI to query if the service is initialized.
  static bool get isInitialized => _isInitialized;

  /// Public getter for current model path (may be null if not set).
  static String? get currentModelPath => _modelAssetPath;

  /// Public getter for last error for debugging.
  static String? get lastErrorMessage => lastError;

  // --- CHAT HISTORY MANAGEMENT ---
  static final List<Map<String, String>> _chatHistory = [];

  // System prompt logic
  static String _systemPrompt = kMedicalSafetyPrompt;
  static String get currentPromptLabel => kMedicalSafetyPromptLabel;

  /// Updates the system prompt used by the LLM.
  static void setSystemPrompt(String newPrompt) {
    if (kDebugMode) {
      print('Updating system prompt to: "$newPrompt"');
    }
    _systemPrompt = newPrompt;
    clearHistory();
  }

  /// Clears the current chat history.
  static void clearHistory() {
    _chatHistory.clear();
    if (kDebugMode) {
      print('Chat history cleared.');
    }
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _modelManager.initialize();
      _modelAssetPath =
          await _modelManager.getSelectedModelPath() ?? AppPaths.gemma3WebModel;

      // Wait briefly for the JS bridge to be available (module may load async).
      const int maxWaitMs = 5000;
      const int intervalMs = 200;
      int waited = 0;
      while (_mediapipeGenai == null && waited < maxWaitMs) {
        if (kDebugMode) {
          print('Waiting for MediapipeGenai JS bridge... (${waited}ms)');
        }
        await Future.delayed(Duration(milliseconds: intervalMs));
        waited += intervalMs;
      }

      final mp = _mediapipeGenai;
      if (mp == null) {
        lastError = 'MediapipeGenai JS bridge not found.';
        throw Exception(lastError);
      }

      final options = InitOptions(
        modelAssetPath: _modelAssetPath!,
        tasksModulePath: AppPaths.tasksModulePath,
        wasmBasePath: AppPaths.wasmBasePath,
        cpuOnly: preferCpuOnly,
        maxTokens: maxTokens,
      );

      await mp.init(options).toDart;
      _isInitialized = true;
      lastError = null;
      if (kDebugMode) {
        print(
          'LLMService initialized successfully with model: $_modelAssetPath',
        );
      }
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  /// Formats the chat history and new query using the
  /// EXACT prompt template specified by the model's configuration.
  static String _formatChatPrompt(String newUserQuery) {
    final StringBuffer prompt = StringBuffer();

    // 1. Start of Sequence Token
    prompt.write('<bos>');

    // 2. Conversation History & System Prompt
    if (_chatHistory.isEmpty) {
      // FIRST TURN: Embed System Prompt with User Query
      final systemAndQuery = '$_systemPrompt\n\n$newUserQuery';
      // Add the combined instruction using the model's defined prefix/suffix
      prompt.write(
        '<start_of_turn>user\n$systemAndQuery\n<end_of_turn>\n<start_of_turn>model\n',
      );
    } else {
      // --- SUBSEQUENT TURNS: History + New Query ---
      for (final turn in _chatHistory) {
        // User Turn (Prefix + Query + Suffix/Prefix)
        prompt.write('<start_of_turn>user\n${turn['user']}\n<end_of_turn>\n');

        // Model Turn (Prefix + Response + Suffix/Prefix)
        // Note: The model's response already contains the end token if it completed generation
        // but we still add the full template structure for context consistency.
        prompt.write(
          '<start_of_turn>model\n${turn['assistant']}\n<end_of_turn>\n',
        );
      }
      // Add the NEW query
      prompt.write('<start_of_turn>user\n$newUserQuery\n<end_of_turn>\n');
      // Signal the model that it's the assistant's turn to respond
      prompt.write('<start_of_turn>model\n');
    }

    return prompt.toString();
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      lastError = 'LLM not initialized. Please initialize first.';
      throw Exception(lastError);
    }
    final mp = _mediapipeGenai;
    if (mp == null) {
      lastError = 'MediapipeGenai JS bridge not found.';
      throw Exception(lastError);
    }

    // Keep history small to avoid exceeding model token limits
    const int maxHistoryTurns = 3;
    if (_chatHistory.length > maxHistoryTurns) {
      _chatHistory.removeRange(0, _chatHistory.length - maxHistoryTurns);
      if (kDebugMode) {
        print(
          'Trimmed chat history to last $maxHistoryTurns turns to avoid token overflow.',
        );
      }
    }

    // 1. Format the full prompt string
    final formattedPrompt = _formatChatPrompt(prompt);

    if (kDebugMode) {
      print('\n--- FULL PROMPT SENT TO MODEL (FINAL TEMPLATE) ---');
      print(formattedPrompt);
    }

    // 2. Generate the response with retry logic on token-limit errors
    String? fullResult;
    try {
      final jsPromise = mp.generate(formattedPrompt);
      final dartResult = await jsPromise.toDart;
      fullResult = dartResult?.toString();
    } catch (e) {
      lastError = e.toString();
      // If the model complains about input length, try truncating history and retry once
      final errText = e.toString();
      if (kDebugMode) print('Error from JS generate(): $errText');

      if (errText.contains('Input is too long') ||
          errText.contains('maxTokens')) {
        if (kDebugMode) {
          print(
            'Detected token-length error. Retrying with cleared history...',
          );
        }
        // Retry with cleared history (one attempt)
        final backupHistory = List<Map<String, String>>.from(_chatHistory);
        _chatHistory.clear();
        try {
          final retryPrompt = _formatChatPrompt(prompt);
          final retryResult = await mp.generate(retryPrompt).toDart;
          fullResult = retryResult?.toString();
          lastError = null;
        } catch (e2) {
          // restore history and rethrow
          _chatHistory.clear();
          _chatHistory.addAll(backupHistory);
          lastError = e2.toString();
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    // 3. Extract and Clean the Model's Text
    String cleanResponse = _cleanModelOutput(fullResult ?? '');
    // 4. Update the chat history
    _chatHistory.add({'user': prompt, 'assistant': cleanResponse});

    lastError = null;
    return cleanResponse;
  }

  /// Cleans the raw output string from the model.
  static String _cleanModelOutput(String rawOutput) {
    // The generation *should* start immediately after the last token: <start_of_turn>model\n
    // We clean up any potential trailing template tokens the model might have generated.

    // Strip the start-of-sequence token if the model accidentally included it in the output
    rawOutput = rawOutput.replaceAll('<bos>', '').trim();

    // The primary stop token is '<end_of_turn>' or '<eos>', so we remove them
    rawOutput = rawOutput.replaceAll('<end_of_turn>', '').trim();
    rawOutput = rawOutput.replaceAll('<eos>', '').trim();

    // Also remove any stray system/user tokens
    rawOutput = rawOutput.replaceAll('<start_of_turn>user', '').trim();
    rawOutput = rawOutput.replaceAll('<start_of_turn>model', '').trim();

    return rawOutput;
  }

  static void dispose() {
    final mp = _mediapipeGenai;
    if (mp != null) {
      try {
        mp.dispose();
      } catch (_) {}
    }
    _isInitialized = false;
    _modelAssetPath = null;
    _chatHistory.clear();
    lastError = null;
  }
}
