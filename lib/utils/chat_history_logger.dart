// Platform-conditional chat history logger wrapper.
// On IO platforms (Android/iOS/macOS/Windows/Linux) we write to files.
// On Web we persist CSV data in browser storage via shared_preferences.

import 'chat_history_logger_io.dart'
    if (dart.library.html) 'chat_history_logger_web.dart'
    as impl;

class ChatHistoryLogger {
  /// Logs a single model response to a CSV-like sink.
  static Future<void> logModelEval({
    required String modelName,
    required String userQuestion,
    required String modelResponse,
    required int responseTimeMs,
    String promptLabel = 'default',
    String? timestampIso,
  }) async {
    await impl.logModelEvalImpl(
      modelName: modelName,
      userQuestion: userQuestion,
      modelResponse: modelResponse,
      responseTimeMs: responseTimeMs,
      promptLabel: promptLabel,
      timestampIso: timestampIso,
    );
  }
}
