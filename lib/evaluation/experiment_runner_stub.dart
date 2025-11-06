// Stub file - should not be used, web version will be used instead
Future<String> runLLMExperimentFromCsvStringImpl({
  required String csvContent,
  String? outputCsvPath,
  required List prompts,
  required Future<String> Function(String prompt) generate,
  int maxQuestions = -1,
  Duration cooldownBetweenCalls = Duration.zero,
}) {
  throw UnsupportedError('Experiment runner not available on this platform');
}
