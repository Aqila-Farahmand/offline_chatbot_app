import 'dart:io';
import 'package:flutter/widgets.dart';

import 'package:medico_ai/services/llm_service.dart';
import 'package:medico_ai/evaluation/experiment_runner.dart';

Future<void> main() async {
  // Ensure Flutter bindings so path_provider works in this headless entry
  WidgetsFlutterBinding.ensureInitialized();

  // Configure dataset and output paths
  final projectRoot = Directory.current.path;
  final datasetCsv = '$projectRoot/evaluation/dataset/questions.csv';
  final outputCsv = '$projectRoot/evaluation/results/model_name_results.csv';

  // Define prompt variants
  final prompts = <PromptSpec>[
    const PromptSpec(
      label: 'baseline_50_words',
      template: 'You are a helpful assistant. Answer in no more than 50 words.\n\nQuestion: {question}\nAnswer:',
    ),
    const PromptSpec(
      label: 'medical_safety_50_words',
      template:
          'You are a medical information assistant. Provide general, non-diagnostic information, and encourage consulting a professional for personal advice. Answer in no more than 50 words.\n\nQuestion: {question}\nAnswer:',
    ),
  ];

  await runExperimentWithLLMService(
    datasetCsvPath: datasetCsv,
    prompts: prompts,
    outputCsvPath: outputCsv,
    maxQuestions: -1,
    cooldownBetweenCalls: const Duration(milliseconds: 250),
    initialize: () async => LLMService.initialize(),
    dispose: () async => LLMService.dispose(),
    generate: (prompt) => LLMService.generateResponse(prompt),
  );
}


