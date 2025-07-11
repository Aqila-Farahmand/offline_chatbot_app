import 'dart:io';

import 'package:path/path.dart' as p;
// Removed path_provider; write directly to a folder relative to the current working directory.

class ChatHistoryLogger {
  // Returns the log file for the current date, creating directories/file + header if needed.
  static Future<File> _getLogFile() async {
    // Base directory is where the application was launched (project root during development).
    final baseDir = Directory.current;
    final logDir = Directory(p.join(baseDir.path, 'chat_logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final String date = DateTime.now()
        .toIso8601String()
        .split('T')
        .first; // YYYY-MM-DD
    final filePath = p.join(logDir.path, 'chat_history_$date.csv');
    final file = File(filePath);

    if (!await file.exists()) {
      // Create file and write header row
      await file.writeAsString('question,response\n');
    }

    return file;
  }

  /// Logs a single user [question] and LLM [response] pair to the CSV file.
  static Future<void> log(String question, String response) async {
    try {
      final file = await _getLogFile();

      String sanitize(String value) {
        // Escape double-quotes by doubling them and strip line breaks.
        return value
            .replaceAll('"', '""')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ');
      }

      final sanitizedQuestion = sanitize(question);
      final sanitizedResponse = sanitize(response);
      final csvLine = '"$sanitizedQuestion","$sanitizedResponse"\n';

      await file.writeAsString(csvLine, mode: FileMode.append, flush: true);
    } catch (e) {
      // Failure to write should not break the app; just log the error.
      print('ChatHistoryLogger error: $e');
    }
  }
}
