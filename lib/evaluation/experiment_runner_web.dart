import 'dart:async';
import 'dart:convert';
import '../utils/chat_history_logger.dart';
import '../services/model_manager.dart';
import '../utils/csv_download.dart';
import '../config/prompt_configs.dart' show PromptSpec;

/// Web-compatible version: collects CSV in memory and triggers download
Future<String> runLLMExperimentFromCsvStringImpl({
  required String csvContent,
  String? outputCsvPath, // Ignored on web
  required List<PromptSpec> prompts,
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) async {
  final model = ModelManager().selectedModel;
  final modelName = model?.name ?? model?.filename ?? 'unknown_model';

  // Collect CSV rows in memory
  final csvRows = <String>[];
  csvRows.add('time_stamp,model_name,prompt_type,question,answer,response_time_ms');

  final allLines = const LineSplitter().convert(csvContent);
  if (allLines.isEmpty) {
    throw StateError('CSV content is empty');
  }

  // Detect if CSV has a header row with a 'question' column.
  final header = _parseCsvLine(allLines.first);
  final hasStructuredHeader = header.contains('question');

  int processed = 0;
  if (hasStructuredHeader) {
    final questionIdx = header.indexOf('question');
    final hasAnswerColumn = header.contains('answer');
    final answerIdx = hasAnswerColumn ? header.indexOf('answer') : -1;

    for (int lineIdx = 1; lineIdx < allLines.length; lineIdx++) {
      final rawLine = allLines[lineIdx];
      if (rawLine.trim().isEmpty) continue;

      final fields = _parseCsvLine(rawLine);
      if (fields.length <= questionIdx) continue;

      final question = fields[questionIdx];
      final referenceAnswer = (hasAnswerColumn && fields.length > answerIdx)
          ? fields[answerIdx]
          : '';

      for (final spec in prompts) {
        final prompt = spec.renderForQuestion(question);
        final stopwatch = Stopwatch()..start();
        late String modelResponse;
        try {
          modelResponse = await generate(prompt);
        } finally {
          stopwatch.stop();
        }

        final responseMs = stopwatch.elapsedMilliseconds;
        final timestampIso = DateTime.now().toUtc().toIso8601String();

        final row = [
          timestampIso,
          modelName,
          spec.label,
          question,
          referenceAnswer,
          modelResponse,
          responseMs.toString(),
        ].map(_csvEscape).join(',');

        csvRows.add(row);

        // Log to chat history and print to console
        await ChatHistoryLogger.logModelEval(
          modelName: modelName,
          userQuestion: question,
          modelResponse: modelResponse,
          responseTimeMs: responseMs,
          promptLabel: spec.label,
          timestampIso: timestampIso,
        );
        print('[Experiment] [$modelName/${spec.label}] Q: $question');
        print(
          '[Experiment] [$modelName/${spec.label}] A: ${modelResponse.replaceAll('\n', ' ')}',
        );
        print('[Experiment] [$modelName/${spec.label}] took: ${responseMs}ms');

        if (cooldownBetweenCalls > Duration.zero) {
          await Future.delayed(cooldownBetweenCalls);
        }
      }

      processed += 1;
      if (maxQuestions > 0 && processed >= maxQuestions) {
        break;
      }
    }
  } else {
    // Treat each line as a question (headerless single-column file)
    for (final question in allLines) {
      final trimmed = question.trim();
      if (trimmed.isEmpty) continue;

      for (final spec in prompts) {
        final prompt = spec.renderForQuestion(trimmed);
        final stopwatch = Stopwatch()..start();
        late String modelResponse;
        try {
          modelResponse = await generate(prompt);
        } finally {
          stopwatch.stop();
        }

        final responseMs = stopwatch.elapsedMilliseconds;
        final timestampIso = DateTime.now().toUtc().toIso8601String();

        final row = [
          timestampIso,
          modelName,
          spec.label,
          trimmed,
          '',
          modelResponse,
          responseMs.toString(),
        ].map(_csvEscape).join(',');

        csvRows.add(row);

        // Log to chat history and print to console
        await ChatHistoryLogger.logModelEval(
          modelName: modelName,
          userQuestion: trimmed,
          modelResponse: modelResponse,
          responseTimeMs: responseMs,
          promptLabel: spec.label,
          timestampIso: timestampIso,
        );
        print('[Experiment] [$modelName/${spec.label}] Q: $trimmed');
        print(
          '[Experiment] [$modelName/${spec.label}] A: ${modelResponse.replaceAll('\n', ' ')}',
        );
        print('[Experiment] [$modelName/${spec.label}] took: ${responseMs}ms');

        if (cooldownBetweenCalls > Duration.zero) {
          await Future.delayed(cooldownBetweenCalls);
        }
      }

      processed += 1;
      if (maxQuestions > 0 && processed >= maxQuestions) {
        break;
      }
    }
  }

  // Combine all rows into CSV content
  final csvOutput = '${csvRows.join('\n')}\n';

  // Trigger download
  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')[0];
  final filename = 'questions_experiment_$timestamp.csv';
  final downloaded = await downloadCsv(filename, csvOutput);

  if (!downloaded) {
    throw Exception('Failed to download CSV file on web');
  }

  return filename;
}

// CSV parsing helpers
List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
        if (nextIsQuote) {
          buffer.write('"');
          i++; // skip the escaped quote
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else {
      if (char == ',') {
        result.add(buffer.toString());
        buffer.clear();
      } else if (char == '"') {
        inQuotes = true;
      } else {
        buffer.write(char);
      }
    }
  }
  result.add(buffer.toString());
  return result;
}

String _csvEscape(String value) {
  final needsQuoting =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuoting) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
