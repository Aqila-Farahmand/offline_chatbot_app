import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../widgets/model_selector.dart';
import '../widgets/max_tokens_selector.dart';
import '../evaluation/experiment_runner.dart';
import '../services/llm_service.dart';
import '../config/prompt_configs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                'AI Model',
                Icons.psychology_outlined,
                'Select and manage your AI models',
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: ModelSelector(),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(
                context,
                'Model Configuration',
                Icons.tune_outlined,
                'Configure model parameters and behavior',
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: MaxTokensSelector(),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(
                context,
                'Evaluation',
                Icons.science_outlined,
                'Run experiments and evaluate model performance',
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Run Questions Experiment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Execute the questions.csv experiment to evaluate model performance across different prompts.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _runExperiment(context),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('Run Experiment'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runExperiment(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffold = ScaffoldMessenger.of(context);

    try {
      scaffold.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Starting experiment...'),
            ],
          ),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );

      // Load the questions CSV from assets (declared in pubspec)
      final csvContent = await rootBundle.loadString(
        'evaluation/dataset/questions.csv',
      );

      // Prepare output path under app support dir
      final appSupport = await getApplicationSupportDirectory();
      final outDir = Directory('${appSupport.path}/evaluation/results');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final outputCsv = '${outDir.path}/questions_experiment.csv';

      // Use prompt specifications from constants
      final prompts = <PromptSpec>[
        const PromptSpec(
          label: kBaselinePromptLabel,
          template: kBaselinePrompt,
        ),
        PromptSpec(
          label: kMedicalSafetyPromptLabel,
          template: '$kMedicalSafetyPrompt\n\nQuestion: {question}\nAnswer:',
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
        SnackBar(
          content: Text('Experiment completed. Results saved to $outputCsv'),
          backgroundColor: colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Experiment failed: $e'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
