import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../widgets/model_selector.dart';
import '../evaluation/experiment_runner.dart';
import '../services/llm_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Model Selector',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const ModelSelector(),
              const SizedBox(height: 24),
              const Text(
                'Evaluation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run questions.csv experiment'),
                onPressed: () async {
                  final scaffold = ScaffoldMessenger.of(context);
                  try {
                    scaffold.showSnackBar(
                      const SnackBar(content: Text('Starting experiment...')),
                    );

                    // Load the questions CSV from assets (declared in pubspec)
                    final csvContent = await rootBundle.loadString('evaluation/dataset/questions.csv');

                    // Prepare output path under app support dir
                    final appSupport = await getApplicationSupportDirectory();
                    final outDir = Directory('${appSupport.path}/evaluation/results');
                    if (!await outDir.exists()) {
                      await outDir.create(recursive: true);
                    }
                    final outputCsv = '${outDir.path}/questions_experiment.csv';

                    // Define simple prompt variants
                    final prompts = <PromptSpec>[
                      const PromptSpec(
                        label: 'baseline',
                        template: 'You are a helpful assistant. Answer concisely.\n\nQuestion: {question}\nAnswer:',
                      ),
                      const PromptSpec(
                        label: 'medical_safety',
                        template:
                        'You are a medical information assistant. Provide general, non-diagnostic information, and encourage consulting a doctor for personal advice.\n\nQuestion: {question}\nAnswer:',
                      ),
                    ];

                    await LLMService.initialize();
                    try {
                      await runLLMExperimentFromCsvString(
                        csvContent: csvContent,
                        prompts: prompts,
                        outputCsvPath: outputCsv,
                        generate: (p) => LLMService.generateResponse(p),
                        cooldownBetweenCalls: const Duration(milliseconds: 200),
                      );
                    } finally {
                      LLMService.dispose();
                    }

                    scaffold.showSnackBar(
                      SnackBar(content: Text('Experiment completed. Results saved to $outputCsv')),
                    );
                  } catch (e) {
                    scaffold.showSnackBar(
                      SnackBar(content: Text('Experiment failed: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}