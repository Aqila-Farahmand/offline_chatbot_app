@JS()
library;

// Web implementation using JS bridge defined in web/mediapipe_text.js
import 'dart:async';
import 'dart:js_interop';
import '../config/path_configs.dart';
import 'model_manager.dart';
import '../config/prompt_configs.dart';
import '../config/llm_config.dart';
import '../utils/token_estimator.dart';
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
  static int maxTokens = LLMConfig.defaultMaxTokens;

  // Track if history was truncated (for user feedback)
  static bool _historyWasTruncated = false;
  static bool get historyWasTruncated => _historyWasTruncated;

  // Last error message (for UI/debugging)
  static String? lastError;

  static void setCpuOnly(bool value) {
    preferCpuOnly = value;
    if (kDebugMode) print('LLMService: setCpuOnly=$value');
  }

  static void setMaxTokens(int value) {
    if (value == maxTokens) return; // No change needed

    maxTokens = value;
    if (kDebugMode) {
      print('LLMService: setMaxTokens=$value');
      print(
        'Note: Service must be reinitialized for the change to take effect.',
      );
    }

    // If already initialized, mark for reinitialization
    // The caller should call dispose() and then initialize() to apply the change
    if (_isInitialized) {
      if (kDebugMode) {
        print(
          'LLMService: Service is already initialized. '
          'Call dispose() and initialize() to apply new maxTokens setting.',
        );
      }
    }
  }

  /// Reinitialize the service with current settings (useful after changing maxTokens)
  static Future<void> reinitialize() async {
    if (kDebugMode) {
      print('LLMService: Reinitializing with maxTokens=$maxTokens');
    }
    dispose();
    await initialize();
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

      // Get the selected model path, ensuring it's web-compatible
      final selectedPath = await _modelManager.getSelectedModelPath();
      if (selectedPath == null) {
        // No model selected - try to use the default web model
        _modelAssetPath = AppPaths.gemma3WebModel;
        debugPrint(
          'Warning: No model selected. Using default web model: $_modelAssetPath',
        );
      } else {
        _modelAssetPath = selectedPath;
        // Verify it's a web-compatible model (warn if not)
        if (!_modelAssetPath!.contains('-web.task') &&
            !_modelAssetPath!.endsWith('-web.litertlm')) {
          debugPrint(
            'Warning: Selected model may not be optimized for web: $_modelAssetPath',
          );
          debugPrint(
            'Consider selecting a model with -web.task suffix for better web performance.',
          );
        }
      }

      // Always log model path (helps debug production issues)
      print(
        'LLMService: Starting initialization with model path: $_modelAssetPath',
      );

      // Wait briefly for the JS bridge to be available (module may load async).
      const int maxWaitMs = 15000; // Increased timeout for production
      const int intervalMs = 200;
      int waited = 0;
      while (_mediapipeGenai == null && waited < maxWaitMs) {
        await Future.delayed(Duration(milliseconds: intervalMs));
        waited += intervalMs;
      }

      final mp = _mediapipeGenai;
      if (mp == null) {
        lastError =
            'MediapipeGenai JS bridge not found after ${maxWaitMs}ms. '
            'Make sure mediapipe_text.js is loaded in index.html. '
            'Check browser console (F12) for JavaScript errors.';
        // Always log critical errors, even in production
        print('ERROR: $lastError');
        throw Exception(lastError);
      }

      final options = InitOptions(
        modelAssetPath: _modelAssetPath!,
        tasksModulePath: AppPaths.tasksModulePath,
        wasmBasePath: AppPaths.wasmBasePath,
        cpuOnly: preferCpuOnly,
        maxTokens: maxTokens,
      );

      // Always log initialization attempt (helps debug production issues)
      print(
        'LLMService: Initializing MediapipeGenai with model: $_modelAssetPath',
      );

      try {
        // Add timeout to prevent hanging indefinitely
        // Increased to 90 seconds as MediaPipe can take time to fully initialize
        await mp
            .init(options)
            .toDart
            .timeout(
              const Duration(seconds: 90),
              onTimeout: () {
                throw TimeoutException(
                  'MediaPipe GenAI initialization timed out after 90 seconds. '
                  'The graph may have started but initialization did not complete. '
                  'Check browser console (F12) for MediaPipe status events.',
                );
              },
            );
      } catch (initError) {
        // Capture more detailed error from JavaScript
        final errorStr = initError.toString();
        lastError =
            'MediaPipe GenAI initialization failed: $errorStr\n'
            'Model path: $_modelAssetPath\n'
            'Tasks module: ${AppPaths.tasksModulePath}\n'
            'WASM base: ${AppPaths.wasmBasePath}\n'
            'Check browser console (F12) for detailed JavaScript errors.';
        // Always log errors in production for debugging
        print('ERROR during MediapipeGenai.init: $errorStr');
        rethrow;
      }

      _isInitialized = true;
      lastError = null;
      print('LLMService initialized successfully with model: $_modelAssetPath');
    } catch (e, stackTrace) {
      lastError = e.toString();
      // Always log errors, even in production
      print('LLMService initialization error: $e');
      if (kDebugMode) {
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Formats the chat history and new query using the

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

  /// Smart history truncation with token awareness
  static void _truncateHistoryIfNeeded(String newQuery) {
    _historyWasTruncated = false;

    // Hard limit: never exceed max history turns
    if (_chatHistory.length > LLMConfig.maxHistoryTurns) {
      final removed = _chatHistory.length - LLMConfig.maxHistoryTurns;
      _chatHistory.removeRange(0, removed);
      _historyWasTruncated = true;
      if (kDebugMode) {
        print(
          'Hard limit: Trimmed chat history from ${_chatHistory.length + removed} to ${LLMConfig.maxHistoryTurns} turns.',
        );
      }
    }

    // Estimate tokens for current prompt
    final queryTokens = TokenEstimator.estimateTokens(newQuery);
    final systemTokens = TokenEstimator.estimateTokens(_systemPrompt);
    final availableForHistory = LLMConfig.calculateAvailableHistoryTokens(
      maxTokens,
      queryTokens + systemTokens,
    );

    // Calculate current history tokens
    int currentHistoryTokens = 0;
    for (final entry in _chatHistory) {
      currentHistoryTokens += TokenEstimator.estimateHistoryEntryTokens(entry);
    }

    // If history exceeds available budget, truncate progressively
    if (currentHistoryTokens > availableForHistory) {
      if (kDebugMode) {
        print(
          'Token budget exceeded: History uses $currentHistoryTokens tokens, '
          'but only $availableForHistory available. Truncating...',
        );
      }

      // Progressive truncation: reduce history gradually
      int targetTurns = LLMConfig.preferredHistoryTurns;
      while (targetTurns >= LLMConfig.minHistoryTurns) {
        // Calculate tokens for target number of turns
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
          // This number of turns fits, use it
          if (_chatHistory.length > targetTurns) {
            final removed = _chatHistory.length - targetTurns;
            _chatHistory.removeRange(0, removed);
            _historyWasTruncated = true;
            if (kDebugMode) {
              print(
                'Progressive truncation: Reduced history to $targetTurns turns '
                '($testTokens tokens, within budget of $availableForHistory).',
              );
            }
          }
          return;
        }

        // Try with fewer turns
        targetTurns--;
      }

      // Last resort: keep only minimum history
      if (_chatHistory.length > LLMConfig.minHistoryTurns) {
        final removed = _chatHistory.length - LLMConfig.minHistoryTurns;
        _chatHistory.removeRange(0, removed);
        _historyWasTruncated = true;
        if (kDebugMode) {
          print(
            'Minimum truncation: Reduced history to ${LLMConfig.minHistoryTurns} turns.',
          );
        }
      }
    }
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

    // 1. Proactively truncate history based on token estimation
    _truncateHistoryIfNeeded(prompt);

    // 2. Format the full prompt string
    String formattedPrompt = _formatChatPrompt(prompt);

    // 3. Final safety check: if prompt is still too long, truncate query
    final estimatedTokens = TokenEstimator.estimateFormattedPromptTokens(
      systemPrompt: _systemPrompt,
      history: _chatHistory,
      newQuery: prompt,
    );

    if (estimatedTokens > maxTokens * 0.9) {
      // 90% threshold
      if (kDebugMode) {
        print(
          'Warning: Estimated prompt tokens ($estimatedTokens) approaching limit ($maxTokens). '
          'Truncating user query...',
        );
      }
      // Truncate the query itself as last resort
      final maxQueryTokens = LLMConfig.reservedTokensForQuery;
      final queryTokens = TokenEstimator.estimateTokens(prompt);
      if (queryTokens > maxQueryTokens) {
        prompt = TokenEstimator.truncateToTokenLimit(
          prompt,
          maxQueryTokens,
          fromEnd: false,
        );
        formattedPrompt = _formatChatPrompt(prompt);
        if (kDebugMode) {
          print('Truncated user query to fit token budget.');
        }
      }
    }

    // 4. Generate the response with enhanced retry logic
    String? fullResult;
    int retryAttempt = 0;

    while (retryAttempt <= LLMConfig.maxRetryAttempts) {
      try {
        final jsPromise = mp.generate(formattedPrompt);
        final dartResult = await jsPromise.toDart;
        fullResult = dartResult?.toString();
        lastError = null;
        break; // Success, exit retry loop
      } catch (e) {
        lastError = e.toString();
        final errText = e.toString();

        if (kDebugMode) {
          print(
            'Error from JS generate() (attempt ${retryAttempt + 1}): $errText',
          );
        }

        // Check if it's a token limit error
        final isTokenError =
            errText.contains('Input is too long') ||
            errText.contains('maxTokens') ||
            errText.contains('token') ||
            errText.contains('context') ||
            errText.contains('length');

        if (isTokenError && retryAttempt < LLMConfig.maxRetryAttempts) {
          retryAttempt++;

          if (kDebugMode) {
            print(
              'Token limit error detected. Retry attempt $retryAttempt/${LLMConfig.maxRetryAttempts}...',
            );
          }

          // Progressive retry strategy
          if (LLMConfig.clearHistoryOnRetry) {
            // Clear more history on each retry
            final turnsToKeep = LLMConfig.minHistoryTurns - (retryAttempt - 1);
            if (turnsToKeep >= 0 && _chatHistory.length > turnsToKeep) {
              _chatHistory.removeRange(0, _chatHistory.length - turnsToKeep);
              _historyWasTruncated = true;
              if (kDebugMode) {
                print('Cleared history, keeping $turnsToKeep turns for retry.');
              }
            } else {
              // Last resort: clear all history
              _chatHistory.clear();
              _historyWasTruncated = true;
              if (kDebugMode) {
                print('Cleared all history for retry.');
              }
            }
          }

          // Reformat prompt with reduced history
          formattedPrompt = _formatChatPrompt(prompt);

          // Continue to next retry attempt
          continue;
        } else {
          // Not a token error, or max retries reached
          if (isTokenError && retryAttempt >= LLMConfig.maxRetryAttempts) {
            // Final fallback: try with no history and truncated query
            _chatHistory.clear();
            final truncatedQuery = TokenEstimator.truncateToTokenLimit(
              prompt,
              LLMConfig.reservedTokensForQuery,
              fromEnd: false,
            );
            formattedPrompt = _formatChatPrompt(truncatedQuery);

            try {
              final jsPromise = mp.generate(formattedPrompt);
              final dartResult = await jsPromise.toDart;
              fullResult = dartResult?.toString();
              lastError = null;
              if (kDebugMode) {
                print('Final fallback succeeded with truncated query.');
              }
              break;
            } catch (e2) {
              // Even fallback failed
              lastError =
                  'Token limit exceeded. Please try a shorter question or clear the conversation.';
              rethrow;
            }
          } else {
            // Non-token error, rethrow immediately
            rethrow;
          }
        }
      }
    }

    // 5. Extract and Clean the Model's Text
    String cleanResponse = _cleanModelOutput(fullResult ?? '');

    // 6. Update the chat history
    _chatHistory.add({'user': prompt, 'assistant': cleanResponse});

    return cleanResponse;
  }

  /// Cleans the raw output string from the model.
  static String _cleanModelOutput(String rawOutput) {
    // The generation *should* start immediately after the last token: <start_of_turn>model\n
    // clean up any potential trailing template tokens the model might have generated.

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
