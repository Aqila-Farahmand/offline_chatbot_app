import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:medico_ai/utils/chat_history_logger.dart';

/// Describes a prompt variant to be tested in the experiment.
/// [label] is a short identifier for the prompt (e.g., "baseline", "med_safety").
/// [template] is the text with a `{question}` placeholder that will be replaced
/// by the dataset question.
class PromptSpec {
  final String label;
  final String template;

  const PromptSpec({required this.label, required this.template});

  String renderForQuestion(String question) {
    return template.replaceAll('{question}', question);
  }
}

/// Runs an offline LLM experiment.
///
/// - Reads questions from a CSV at [datasetCsvPath]. The CSV must contain a column
///   named `question`. An optional `answer` column will be ignored by default
///   (kept for reference-only datasets).
/// - For each [PromptSpec] in [prompts], this will call [generate] with the
///   rendered prompt (template with `{question}` substituted), measure response
///   latency, and write rows to [outputCsvPath] with headers:
///   `time_stamp,model_name,prompt_type,question,answer,response_ms`.
/// - [modelName] is recorded for every row to identify the model used.
/// - If [maxQuestions] > 0, only the first N questions will be used.
/// - [cooldownBetweenCalls] adds an optional sleep between back-to-back calls.
///
/// The [generate] callback abstracts the LLM invocation. You can pass a wrapper
/// around your app's LLM service, e.g. `LLMService.generateResponse`.
Future<void> runLLMExperiment({
  required String datasetCsvPath,
  required List<PromptSpec> prompts,
  required String modelName,
  required String outputCsvPath,
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) async {
  final dataset = File(datasetCsvPath);
  if (!await dataset.exists()) {
    throw ArgumentError('Dataset not found at $datasetCsvPath');
  }

  // Ensure output directory exists
  final outFile = File(outputCsvPath);
  await outFile.parent.create(recursive: true);

  // If the file is new/empty, write header
  final needsHeader = !await outFile.exists() || (await outFile.length()) == 0;
  final sink = outFile.openWrite(mode: FileMode.append, encoding: utf8);
  try {
    if (needsHeader) {
      sink.writeln('time_stamp,model_name,prompt_type,question,answer,response_ms');
    }

    // Parse CSV lazily to handle large files without loading all into memory
    final lines = dataset.openRead().transform(utf8.decoder).transform(const LineSplitter());

    // Read header to determine column indices
    final headerLine = await lines.first;
    final header = _parseCsvLine(headerLine);
    final questionIdx = header.indexOf('question');
    final hasAnswerColumn = header.contains('answer');
    final answerIdx = hasAnswerColumn ? header.indexOf('answer') : -1;
    if (questionIdx == -1) {
      throw StateError('Dataset CSV must contain a "question" column');
    }

    // Re-open a new stream to iterate all rows including after header
    final rowStream = dataset.openRead().transform(utf8.decoder).transform(const LineSplitter());

    int processed = 0;
    bool isFirst = true;
    await for (final rawLine in rowStream) {
      // Skip header
      if (isFirst) {
        isFirst = false;
        continue;
      }
      if (rawLine.trim().isEmpty) continue;

      final fields = _parseCsvLine(rawLine);
      if (fields.length <= questionIdx) continue;

      final question = fields[questionIdx];
      final referenceAnswer = (hasAnswerColumn && fields.length > answerIdx) ? fields[answerIdx] : '';

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

        // Escape fields for CSV
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
        print('[Experiment] [$modelName/${spec.label}] A: ${modelResponse.replaceAll('\n', ' ')}');
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
  } finally {
    await sink.flush();
    await sink.close();
  }
}

// --- Minimal CSV helpers ---

/// Parse a single CSV line into fields, handling quotes and commas.
/// Supports RFC4180-style CSV with double-quoted fields, doubled quotes inside,
/// and commas/newlines within quoted fields are not expected here since we parse per line.
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

/// Escape a field value for CSV output.
String _csvEscape(String value) {
  final needsQuoting = value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
  if (!needsQuoting) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

/// Run experiment from CSV content string (e.g., loaded from a bundled asset).
/// The CSV must include a header row with a `question` column. An optional
/// `answer` column is used as `reference_answer` in outputs.
Future<void> runLLMExperimentFromCsvString({
  required String csvContent,
  required List<PromptSpec> prompts,
  required String modelName,
  required String outputCsvPath,
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) async {
  // Ensure output directory exists
  final outFile = File(outputCsvPath);
  await outFile.parent.create(recursive: true);

  // If the file is new/empty, write header
  final needsHeader = !await outFile.exists() || (await outFile.length()) == 0;
  final sink = outFile.openWrite(mode: FileMode.append, encoding: utf8);
  try {
    if (needsHeader) {
      sink.writeln('time_stamp,model_name,prompt_type,question,answer,response_ms');
    }

    final allLines = const LineSplitter().convert(csvContent);
    if (allLines.isEmpty) return;

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
        final referenceAnswer = (hasAnswerColumn && fields.length > answerIdx) ? fields[answerIdx] : '';

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
          print('[Experiment] [$modelName/${spec.label}] A: ${modelResponse.replaceAll('\n', ' ')}');
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
          print('[Experiment] [$modelName/${spec.label}] A: ${modelResponse.replaceAll('\n', ' ')}');
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
  } finally {
    await sink.flush();
    await sink.close();
  }
}

/// Convenience wrapper to run the experiment using the app's LLM service.
///
/// This expects the caller to run in a Flutter context where the `path_provider`
/// plugin works. It will initialize and dispose the service automatically.
Future<void> runExperimentWithLLMService({
  required String datasetCsvPath,
  required List<PromptSpec> prompts,
  required String modelName,
  required String outputCsvPath,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
  Future<void> Function()? initialize,
  Future<void> Function()? dispose,
  required Future<String> Function(String prompt) generate,
}) async {
  // Allow callers to inject custom lifecycle hooks; otherwise, call none.
  if (initialize != null) {
    await initialize();
  }
  try {
    await runLLMExperiment(
      datasetCsvPath: datasetCsvPath,
      prompts: prompts,
      modelName: modelName,
      outputCsvPath: outputCsvPath,
      generate: generate,
      maxQuestions: maxQuestions,
      cooldownBetweenCalls: cooldownBetweenCalls,
    );
  } finally {
    if (dispose != null) {
      await dispose();
    }
  }
}


