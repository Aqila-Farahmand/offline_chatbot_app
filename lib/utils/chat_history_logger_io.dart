import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _getLogFile() async {
  Directory base;
  try {
    base = await getApplicationDocumentsDirectory();
  } catch (_) {
    base = await getTemporaryDirectory();
  }

  final logDir = Directory(p.join(base.path, 'chat_logs'));
  if (!await logDir.exists()) {
    await logDir.create(recursive: true);
  }

  final String date = DateTime.now().toIso8601String().split('T').first;
  final filePath = p.join(logDir.path, 'chat_history_$date.csv');
  final file = File(filePath);

  if (!await file.exists()) {
    await file.writeAsString(
      'timestamp_iso,model_name,prompt_label,question,response,response_time_ms\n',
    );
  }

  return file;
}

String _sanitize(String value) {
  return value
      .replaceAll('"', '""')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');
}

Future<void> logModelEvalImpl({
  required String modelName,
  required String userQuestion,
  required String modelResponse,
  required int responseTimeMs,
  required String promptLabel,
  String? timestampIso,
}) async {
  try {
    final file = await _getLogFile();
    final ts = timestampIso ?? DateTime.now().toUtc().toIso8601String();
    final csvLine =
        '"${_sanitize(ts)}","${_sanitize(modelName)}","${_sanitize(promptLabel)}","${_sanitize(userQuestion)}","${_sanitize(modelResponse)}",$responseTimeMs\n';
    await file.writeAsString(csvLine, mode: FileMode.append, flush: true);
  } catch (e) {
    // Best-effort logging; avoid throwing across app layers
    // ignore: avoid_print
    print('ChatHistoryLogger IO error: $e');
  }
}
