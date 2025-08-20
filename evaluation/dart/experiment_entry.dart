import 'dart:io';
import 'package:flutter/widgets.dart';

import 'package:medico_ai/services/llm_service.dart';
import 'package:medico_ai/services/model_manager.dart';
import 'package:medico_ai/constants/prompts.dart';
import 'package:medico_ai/evaluation/experiment_runner.dart';

Future<void> main() async {
  // Ensure Flutter bindings so path_provider works in this headless entry
  WidgetsFlutterBinding.ensureInitialized();

  // Configure dataset and output paths
  final projectRoot = Directory.current.path;
  final datasetCsv = '$projectRoot/evaluation/dataset/questions.csv';
  final outputCsv = '$projectRoot/evaluation/results/model_name_results.csv';

  // Use the app's default system prompt via LLMService; only pass the raw question here
  final prompts = <PromptSpec>[
    const PromptSpec(
      label: kMedicoAIPromptLabel,
      template: '{question}',
    ),
  ];

  // Initialize once, then derive actual selected model name
  await LLMService.initialize();
  final selectedName = ModelManager().selectedModel?.name ?? ModelManager().selectedModel?.filename ?? 'unknown';
  try {
    await runLLMExperiment(
      datasetCsvPath: datasetCsv,
      prompts: prompts,
      modelName: selectedName,
      outputCsvPath: outputCsv,
      generate: (prompt) => LLMService.generateResponse(prompt),
      maxQuestions: -1,
      cooldownBetweenCalls: const Duration(milliseconds: 250),
    );
  } finally {
    await LLMService.dispose();
  }
}


