/// Token estimation utility
///
/// Provides approximate token counting for managing context windows.
/// Uses a simple heuristic: ~4 characters per token (average for English text).
/// This is a rough approximation but sufficient for proactive truncation.
class TokenEstimator {
  TokenEstimator._(); // Private constructor

  /// Average characters per token (approximation)
  /// Most tokenizers average between 3-5 characters per token for English
  static const double _charsPerToken = 4.0;

  /// Estimate token count from text
  ///
  /// This is an approximation. Actual token counts may vary by model/tokenizer.
  /// Used for proactive truncation to avoid hitting hard limits.
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;

    // Count characters (excluding whitespace for better approximation)
    final charCount = text.replaceAll(RegExp(r'\s+'), ' ').length;

    // Rough estimation: divide by average chars per token
    final estimated = (charCount / _charsPerToken).ceil();

    // Add overhead for special tokens (formatting, turn markers, etc.)
    // Count special tokens in the text
    final specialTokenCount = _countSpecialTokens(text);

    return estimated + specialTokenCount;
  }

  /// Count special tokens that add to token budget
  static int _countSpecialTokens(String text) {
    int count = 0;

    // Count common special tokens used in the prompt format
    final specialTokenPatterns = [
      '<bos>',
      '<eos>',
      '<start_of_turn>',
      '<end_of_turn>',
      '<start_of_turn>user',
      '<start_of_turn>model',
    ];

    for (final pattern in specialTokenPatterns) {
      count += pattern.allMatches(text).length;
    }

    return count;
  }

  /// Estimate tokens for a chat history entry
  static int estimateHistoryEntryTokens(Map<String, String> entry) {
    final userText = entry['user'] ?? '';
    final assistantText = entry['assistant'] ?? '';

    // Each turn has formatting overhead
    const int turnOverhead = 20; // Approximate tokens for turn markers

    return estimateTokens(userText) +
        estimateTokens(assistantText) +
        turnOverhead;
  }

  /// Estimate total tokens for formatted prompt
  ///
  /// Includes system prompt, history, and new query
  static int estimateFormattedPromptTokens({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String newQuery,
  }) {
    int total = 0;

    // System prompt tokens
    total += estimateTokens(systemPrompt);

    // History tokens (with formatting overhead)
    for (final entry in history) {
      total += estimateHistoryEntryTokens(entry);
    }

    // New query tokens
    total += estimateTokens(newQuery);

    // Base formatting overhead (bos, turn markers, etc.)
    const int baseOverhead = 30;
    total += baseOverhead;

    return total;
  }

  /// Truncate text to fit within token budget
  ///
  /// Attempts to preserve meaning by truncating from the middle or end
  /// depending on the use case.
  static String truncateToTokenLimit(
    String text,
    int maxTokens, {
    bool fromEnd = false,
  }) {
    if (estimateTokens(text) <= maxTokens) {
      return text;
    }

    // Binary search for the right length
    int left = 0;
    int right = text.length;
    String bestFit = '';

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final truncated = fromEnd
          ? text.substring(0, mid)
          : text.substring(text.length - mid);

      if (estimateTokens(truncated) <= maxTokens) {
        bestFit = truncated;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return bestFit.isEmpty ? text.substring(0, 100) : bestFit;
  }
}
