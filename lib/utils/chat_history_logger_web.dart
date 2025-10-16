import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKeyPrefix = 'chat_logs_';

String _sanitize(String value) {
  return value
      .replaceAll('"', '""')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');
}

Future<void> _ensureHeader(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing == null || !existing.startsWith('timestamp_iso,')) {
    await prefs.setString(
      key,
      'timestamp_iso,model_name,prompt_label,question,response,response_time_ms\n',
    );
  }
}

Future<void> logModelEvalImpl({
  required String modelName,
  required String userQuestion,
  required String modelResponse,
  required int responseTimeMs,
  String promptLabel = 'default',
  String? timestampIso,
}) async {
  try {
    final date = DateTime.now().toIso8601String().split('T').first;
    final key = '$_prefsKeyPrefix$date';
    await _ensureHeader(key);

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key) ?? '';
    final ts = timestampIso ?? DateTime.now().toUtc().toIso8601String();
    final csvLine =
        '"${_sanitize(ts)}","${_sanitize(modelName)}","${_sanitize(promptLabel)}","${_sanitize(userQuestion)}","${_sanitize(modelResponse)}",$responseTimeMs\n';

    // Append by rewriting the value (web storage is key-value only)
    await prefs.setString(key, existing + csvLine);
  } catch (e) {
    // ignore: avoid_print
    print('ChatHistoryLogger Web error: $e');
  }
}
