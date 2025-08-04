// Dummy Android LLM service for non-Android platforms
class AndroidLLMService {
  Future<void> initialize() async {
    throw UnsupportedError('Android LLM service not available on this platform');
  }

  Future<bool> initLlama(String modelPath) async {
    throw UnsupportedError('Android LLM service not available on this platform');
  }

  Future<String> generateText(String prompt) async {
    throw UnsupportedError('Android LLM service not available on this platform');
  }

  void freeLlama() {
    // No-op for dummy service
  }

  void dispose() {
    // No-op for dummy service
  }
} 