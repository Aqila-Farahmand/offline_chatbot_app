/// External URLs and API endpoints
///
/// This file contains all external URLs used by the application.
/// These should be used instead of hardcoded URLs throughout the codebase.
class ExternalUrls {
  ExternalUrls._(); // Private constructor to prevent instantiation

  // ============================================================================
  // Hugging Face URLs
  // ============================================================================
  /// Hugging Face base URL
  static const String huggingFaceBase = 'https://huggingface.co';

  /// Hugging Face join/signup URL
  static const String huggingFaceJoin = 'https://huggingface.co/join';

  /// Hugging Face login URL
  static const String huggingFaceLogin = 'https://huggingface.co/login';

  /// Hugging Face settings tokens URL
  static const String huggingFaceSettingsTokens =
      'https://huggingface.co/settings/tokens';

  // ============================================================================
  // Model Download URLs
  // ============================================================================
  /// Gemma 2B model download URL
  static const String gemma2bModelUrl =
      'https://huggingface.co/google/gemma-2b-it/resolve/main/gemma-2b-q4.gguf';

  /// TinyLlama 1.1B Chat model download URL
  static const String tinyllama11bChatModelUrl =
      'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat.Q4_K_M.gguf';

  /// Qwen2.5 1.5B Instruct model download URL
  static const String qwen25_15bInstructModelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';

  /// Gemma 3N E2B it litert lm model download URL
  static const String gemma3nE2bItLitertLmModelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4-Web.litertlm';

  // ============================================================================
  // Helper Methods
  // ============================================================================
  /// Construct a Hugging Face model page URL from model path parts
  ///
  /// Example: ['google', 'gemma-2b-it'] -> 'https://huggingface.co/google/gemma-2b-it'
  static String getHuggingFaceModelPageUrl(List<String> pathParts) {
    if (pathParts.length >= 2) {
      return '$huggingFaceBase/${pathParts[0]}/${pathParts[1]}';
    }
    return huggingFaceBase;
  }
}
