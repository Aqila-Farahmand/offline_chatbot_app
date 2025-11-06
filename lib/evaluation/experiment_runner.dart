// Conditional imports for platform-specific implementations
import 'experiment_runner_stub.dart'
    if (dart.library.io) 'experiment_runner_io.dart'
    if (dart.library.html) 'experiment_runner_web.dart'
    as impl;
import 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_io.dart'
    as file_reader;
import '../config/prompt_configs.dart' show PromptSpec;

/// Runs an offline LLM experiment from a file path.
///
/// NOTE: This function is only available on non-web platforms (uses dart:io).
/// For web compatibility, use runLLMExperimentFromCsvString instead.
///
/// - Reads questions from a CSV at [datasetCsvPath]. The CSV must contain a column
///   named `question`. An optional `answer` column will be ignored by default
///   (kept for reference-only datasets).
/// - For each [PromptSpec] in [prompts], this will call [generate] with the
///   rendered prompt (template with `{question}` substituted), measure response
///   latency, and write rows to [outputCsvPath] with headers:
///   `time_stamp,model_name,prompt_type,question,answer,response_ms`.
/// - The model name is fetched automatically from ModelManager's selected model.
/// - If [maxQuestions] > 0, only the first N questions will be used.
/// - [cooldownBetweenCalls] adds an optional sleep between back-to-back calls.
///
/// The [generate] callback abstracts the LLM invocation. You can pass a wrapper
/// around your app's LLM service, e.g. `LLMService.generateResponse`.
@Deprecated(
  'Use runLLMExperimentFromCsvString for cross-platform compatibility',
)
Future<void> runLLMExperiment({
  required String datasetCsvPath,
  required List<PromptSpec> prompts,
  required String outputCsvPath,
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) {
  throw UnsupportedError(
    'runLLMExperiment is not available on web. Use runLLMExperimentFromCsvString instead.',
  );
}

/// Run experiment from CSV content string (e.g., loaded from a bundled asset).
/// The CSV must include a header row with a `question` column. An optional
/// `answer` column is used as `reference_answer` in outputs.
///
/// On web, this will trigger a CSV download. On other platforms, it writes to a file.
Future<String> runLLMExperimentFromCsvString({
  required String csvContent,
  required List<PromptSpec> prompts,
  String? outputCsvPath, // Optional on web, required on IO
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) {
  return impl.runLLMExperimentFromCsvStringImpl(
    csvContent: csvContent,
    outputCsvPath: outputCsvPath,
    prompts: prompts,
    generate: generate,
    maxQuestions: maxQuestions,
    cooldownBetweenCalls: cooldownBetweenCalls,
  );
}

/// Convenience wrapper to run the experiment using the app's LLM service.
///
/// This expects the caller to run in a Flutter context where the `path_provider`
/// plugin works. It will initialize and dispose the service automatically.
///
/// NOTE: This function reads from a file path and is not available on web.
/// For web compatibility, use runLLMExperimentFromCsvString with CSV content directly.
Future<void> runExperimentWithLLMService({
  required String datasetCsvPath,
  required List<PromptSpec> prompts,
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
    // Read CSV file content and use the cross-platform function
    final csvContent = await _readCsvFile(datasetCsvPath);
    await runLLMExperimentFromCsvString(
      csvContent: csvContent,
      prompts: prompts,
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

/// Helper function to read CSV file content (non-web only)
Future<String> _readCsvFile(String filePath) async {
  return await file_reader.readCsvFile(filePath);
}
