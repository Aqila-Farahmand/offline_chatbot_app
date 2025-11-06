import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/chat_history_logger.dart';
import '../services/model_manager.dart';
import '../config/prompt_configs.dart' show PromptSpec;

/// IO version: writes to file system
Future<String> runLLMExperimentFromCsvStringImpl({
  required String csvContent,
  String? outputCsvPath,
  required List<PromptSpec> prompts,
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) async {
  if (outputCsvPath == null) {
    throw ArgumentError('outputCsvPath is required on non-web platforms');
  }
  final model = ModelManager().selectedModel;
  final modelName = model?.name ?? model?.filename ?? 'unknown_model';

  // Ensure output directory exists
  final outFile = File(outputCsvPath);
  await outFile.parent.create(recursive: true);

  // If the file is new/empty, write header
  final needsHeader = !await outFile.exists() || (await outFile.length()) == 0;
  final sink = outFile.openWrite(mode: FileMode.append, encoding: utf8);
  try {
    if (needsHeader) {
      sink.writeln(
        'time_stamp,model_name,prompt_type,question,answer,response_time_ms',
      );
    }

    final allLines = const LineSplitter().convert(csvContent);
    if (allLines.isEmpty) return outputCsvPath;

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

          sink.writeln(row);

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
          print(
            '[Experiment] [$modelName/${spec.label}] took: ${responseMs}ms',
          );

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

          sink.writeln(row);

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
          print(
            '[Experiment] [$modelName/${spec.label}] took: ${responseMs}ms',
          );

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
  } finally {
    await sink.flush();
    await sink.close();
  }

  return outputCsvPath;
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
