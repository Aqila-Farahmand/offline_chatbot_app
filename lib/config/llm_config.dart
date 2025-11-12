/// LLM-specific configuration constants
///
/// This file contains configuration for LLM token limits, history management,
/// and response generation strategies.
class LLMConfig {
  LLMConfig._(); // Private constructor to prevent instantiation

  // ============================================================================
  // Token Limits
  // ============================================================================
  /// Default max tokens for response generation (web)
  static const int defaultMaxTokens = 1280;

  /// Maximum tokens for small models
  static const int maxTokensSmall = 512;

  /// Maximum tokens for medium models
  static const int maxTokensMedium = 1024;

  /// Maximum tokens for large models (default)
  static const int maxTokensLarge = 1280;

  /// Maximum tokens for very large models
  static const int maxTokensVeryLarge = 2048;

  /// Maximum tokens for extremely large models
  static const int maxTokensExtreme = 4096;

  // ============================================================================
  // Context Window Management
  // ============================================================================
  /// Maximum number of history turns to keep (conservative limit)
  /// This is a hard limit - history beyond this is always removed
  static const int maxHistoryTurns = 5;

  /// Preferred number of history turns (soft limit)
  /// History is trimmed to this when approaching token limits
  static const int preferredHistoryTurns = 3;

  /// Minimum history turns to preserve
  /// Even when truncating, keep at least this many recent turns
  static const int minHistoryTurns = 1;

  /// Token budget reserved for system prompt and formatting
  /// This is subtracted from available context when calculating history limits
  static const int reservedTokensForSystem = 200;

  /// Token budget reserved for new user query
  /// Ensures we always have room for the current question
  static const int reservedTokensForQuery = 300;

  /// Safety margin for token estimation
  /// Since token estimation is approximate, add this buffer
  static const int tokenEstimationBuffer = 100;

  // ============================================================================
  // Truncation Strategy
  // ============================================================================
  /// Current truncation strategy (progressive degradation by default)
  /// Progressive: reduce history gradually
  /// Aggressive: clear all history if needed
  /// Smart: summarize old history instead of deleting (future feature)
  static const String truncationStrategy = 'progressive';

  // ============================================================================
  // Retry Configuration
  // ============================================================================
  /// Maximum retry attempts when hitting token limits
  static const int maxRetryAttempts = 2;

  /// Whether to clear history on retry
  static const bool clearHistoryOnRetry = true;

  /// Whether to reduce max tokens on retry
  static const bool reduceMaxTokensOnRetry = false;

  // ============================================================================
  // Helper Methods
  // ============================================================================
  /// Calculate available token budget for history
  ///
  /// Given max tokens and current query, calculate how many tokens
  /// can be used for chat history.
  static int calculateAvailableHistoryTokens(int maxTokens, int queryTokens) {
    return maxTokens -
        reservedTokensForSystem -
        queryTokens -
        tokenEstimationBuffer;
  }

  /// Get recommended max tokens based on model size
  static int getRecommendedMaxTokens(String? modelName) {
    if (modelName == null) return defaultMaxTokens;

    final lowerName = modelName.toLowerCase();

    if (lowerName.contains('tiny') ||
        lowerName.contains('1b') ||
        lowerName.contains('1.1b')) {
      return maxTokensSmall;
    } else if (lowerName.contains('2b') || lowerName.contains('1.5b')) {
      return maxTokensMedium;
    } else if (lowerName.contains('3b') || lowerName.contains('7b')) {
      return maxTokensLarge;
    } else if (lowerName.contains('13b') || lowerName.contains('30b')) {
      return maxTokensVeryLarge;
    } else {
      return defaultMaxTokens;
    }
  }
}
