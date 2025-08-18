import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ChatHistoryLogger {
  static Directory? _cachedLogDir;

  static Future<Directory> _resolveLogDir() async {
    if (_cachedLogDir != null) return _cachedLogDir!;

    Directory base;
    try {
      // Use app-internal documents directory for reliability (always writable)
      // Android path: /data/user/0/<package>/app_flutter
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      // Fallback to temp dir if anything goes wrong
      base = await getTemporaryDirectory();
    }

    final logDir = Directory(p.join(base.path, 'chat_logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    print('[ChatHistoryLogger] Logs directory: ${logDir.path}');
    _cachedLogDir = logDir;
    return logDir;
  }

  /// Returns the log file for the current date, creating directories/file + header if needed.
  static Future<File> _getLogFile() async {
    final logDir = await _resolveLogDir();

    final String date = DateTime.now()
        .toIso8601String()
        .split('T')
        .first; // YYYY-MM-DD
    final filePath = p.join(logDir.path, 'chat_history_$date.csv');
    final file = File(filePath);

    if (!await file.exists()) {
      // Create file and write header row
      await file.writeAsString(
        'model_name,question,response,response_time_ms\n',
      );
    }

    return file;
  }

  /// Logs a single model response to the CSV file.
  static Future<void> logModelEval({
    required String modelName,
    required String userQuestion,
    required String modelResponse,
    required int responseTimeMs,
  }) async {
    try {
      final file = await _getLogFile();

      String sanitize(String value) {
        // Escape double-quotes by doubling them and strip line breaks.
        return value
            .replaceAll('"', '""')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ');
      }

      final csvLine =
          '"${sanitize(modelName)}","${sanitize(userQuestion)}","${sanitize(modelResponse)}",$responseTimeMs\n'
              .replaceFirst('userQuestion', 'question')
              .replaceFirst('modelResponse', 'response');
      await file.writeAsString(csvLine, mode: FileMode.append, flush: true);
    } catch (e) {
      print('ChatHistoryLogger error: $e');
    }
  }
}
