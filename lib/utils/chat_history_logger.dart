import 'dart:io';

import 'package:path/path.dart' as p;
// Removed path_provider; write directly to a folder relative to the current working directory.

class ChatHistoryLogger {
  static Directory? _cachedLogDir;

  static Future<Directory> _resolveLogDir() async {
    if (_cachedLogDir != null) return _cachedLogDir!;

    final initialDir = Directory.current;
    Directory dir = initialDir;

    // Walk up directories until we find pubspec.yaml or reach root.
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (await pubspec.exists()) {
        break;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        // Reached filesystem root; no pubspec found. Use the initial directory.
        dir = initialDir;
        break;
      }
      dir = parent;
    }

    final logDir = Directory(p.join(dir.path, 'chat_logs'));
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
