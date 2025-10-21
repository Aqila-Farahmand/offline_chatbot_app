@JS()
library;
// Web implementation using JS bridge defined in web/mediapipe_text.js
import 'dart:async';
import 'dart:js_interop';
import '../constants/paths.dart';
import 'model_manager.dart';
import '../constants/prompts.dart';
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
  });
}

class LLMService {
  static bool _isInitialized = false;
  static final ModelManager _modelManager = ModelManager();
  static String? _modelAssetPath = AppPaths.gemma3WebModel;

  // --- CHAT HISTORY MANAGEMENT ---
  static final List<Map<String, String>> _chatHistory = [];

  // System prompt logic
  static String _systemPrompt = kMedicoAISystemPrompt;
  static String get currentPromptLabel => kMedicoAIPromptLabel;

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

    await _modelManager.initialize();
    _modelAssetPath = await _modelManager.getSelectedModelPath() ?? AppPaths.gemma3WebModel;

    final mp = _mediapipeGenai;
    if (mp == null) {
      throw Exception('MediapipeGenai JS bridge not found.');
    }

    final options = InitOptions(
      modelAssetPath: _modelAssetPath!,
      tasksModulePath: AppPaths.tasksModulePath,
      wasmBasePath: AppPaths.wasmBasePath,
    );

    await mp.init(options).toDart;
    _isInitialized = true;
    if (kDebugMode) {
      print('LLMService initialized successfully with model: $_modelAssetPath');
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
        prompt.write('<start_of_turn>user\n$systemAndQuery\n<end_of_turn>\n<start_of_turn>model\n');

    } else {
        // --- SUBSEQUENT TURNS: History + New Query ---
        for (final turn in _chatHistory) {
          // User Turn (Prefix + Query + Suffix/Prefix)
          prompt.write('<start_of_turn>user\n${turn['user']}\n<end_of_turn>\n');

          // Model Turn (Prefix + Response + Suffix/Prefix)
          // Note: The model's response already contains the end token if it completed generation
          // but we still add the full template structure for context consistency.
          prompt.write('<start_of_turn>model\n${turn['assistant']}\n<end_of_turn>\n');
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
      throw Exception('LLM not initialized. Please initialize first.');
    }
    final mp = _mediapipeGenai;
    if (mp == null) {
      throw Exception('MediapipeGenai JS bridge not found.');
    }

    // 1. Format the full prompt string
    final formattedPrompt = _formatChatPrompt(prompt);

    if (kDebugMode) {
        print('\n--- FULL PROMPT SENT TO MODEL (FINAL TEMPLATE) ---');
        print(formattedPrompt);
        print('--------------------------------------------------');
    }
    // 2. Generate the response
    final fullResult = await mp.generate(formattedPrompt).toDart as String?;

    // 3. Extract and Clean the Model's Text
    String cleanResponse = _cleanModelOutput(fullResult ?? '');
    // 4. Update the chat history
    _chatHistory.add({
      'user': prompt,
      'assistant': cleanResponse,
    });

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
  }
}
