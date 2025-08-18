import 'dart:io';
import 'package:flutter/widgets.dart';

import 'package:medico_ai/services/llm_service.dart';
import 'experiment_runner.dart';

Future<void> main() async {
  // Ensure Flutter bindings so path_provider works in this headless entry
  WidgetsFlutterBinding.ensureInitialized();

  // Configure dataset and output paths
  final projectRoot = Directory.current.path;
  final datasetCsv = '$projectRoot/evaluation/dataset/test.csv';
  final outputCsv = '$projectRoot/evaluation/results/llm_experiment_results.csv';

  // Define prompt variants
  final prompts = <PromptSpec>[
    const PromptSpec(
      label: 'baseline',
      template: 'You are a helpful assistant. Answer concisely.\n\nQuestion: {question}\nAnswer:',
    ),
    const PromptSpec(
      label: 'medical_safety',
      template:
          'You are a medical information assistant. Provide general, non-diagnostic information, and encourage consulting a professional for personal advice.\n\nQuestion: {question}\nAnswer:',
    ),
  ];

  await runExperimentWithLLMService(
    datasetCsvPath: datasetCsv,
    prompts: prompts,
    modelName: 'selected_model', // This is just a label written to CSV
    outputCsvPath: outputCsv,
    maxQuestions: -1,
    cooldownBetweenCalls: const Duration(milliseconds: 250),
    initialize: () async => LLMService.initialize(),
    dispose: () async => LLMService.dispose(),
    generate: (prompt) => LLMService.generateResponse(prompt),
  );
}


