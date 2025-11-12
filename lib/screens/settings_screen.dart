import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../widgets/model_selector.dart';
import '../widgets/max_tokens_selector.dart';
import '../evaluation/experiment_runner.dart';
import '../services/llm_service.dart';
import '../config/prompt_configs.dart';
import '../config/firebase_config.dart';
import '../config/app_constants.dart';
import '../services/privacy_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          final user = authSnap.data;
          final isAdmin = FirebaseConfig.isAdmin(user);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Model section - Available to all users
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
                  // Privacy & Data Collection section - All users
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    context,
                    'Privacy & Data Collection',
                    Icons.privacy_tip_outlined,
                    'Control your data sharing preferences',
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
                    child: _buildPrivacySettings(context, colorScheme),
                  ),
                  // Model Configuration (Token Settings) - Admin only
                  if (isAdmin) ...[
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
                  ],
                  // Evaluation section - Admin only
                  if (isAdmin) ...[
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivacySettings(BuildContext context, ColorScheme colorScheme) {
    return FutureBuilder<bool>(
      future: PrivacyService.isRemoteLoggingEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Privacy notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Research Data Collection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MedicoAI is a prototype app. Chat history may be collected '
                    'for research and study purposes only. You can opt-in or '
                    'opt-out at any time. Your privacy is our priority.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Consent toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Chat History for Research',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnabled
                            ? 'Your chat history is being shared anonymously for research purposes.'
                            : 'Chat history is not being shared. Your conversations remain private.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Show consent dialog before enabling
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Research Data Collection',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'By enabling this, you consent to:',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildConsentItem(
                                context,
                                'Your chat history will be collected for research purposes only',
                                colorScheme,
                              ),
                              _buildConsentItem(
                                context,
                                'Data is anonymized and used to improve the prototype',
                                colorScheme,
                              ),
                              _buildConsentItem(
                                context,
                                'You can opt-out at any time in settings',
                                colorScheme,
                              ),
                              _buildConsentItem(
                                context,
                                'Your privacy and data security are our priority',
                                colorScheme,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('I Consent'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await PrivacyService.setConsentForRemoteLogging(true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Research data collection enabled. Thank you for contributing!',
                              ),
                              backgroundColor: colorScheme.primaryContainer,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } else {
                      // Disable immediately
                      await PrivacyService.setRemoteLoggingEnabled(false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Research data collection disabled. Your chat history will no longer be shared.',
                            ),
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Data deletion option
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Request Data Deletion',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    content: Text(
                      'This will disable data collection and request deletion of your '
                      'existing chat history from our research database. '
                      'Contact an administrator for immediate deletion.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.errorContainer,
                          foregroundColor: colorScheme.onErrorContainer,
                        ),
                        child: const Text('Request Deletion'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final success = await PrivacyService.requestDataDeletion();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Data collection disabled. Contact admin for data deletion.'
                              : 'Error processing request. Please try again.',
                        ),
                        backgroundColor: success
                            ? colorScheme.surfaceContainerHighest
                            : colorScheme.errorContainer,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Request Data Deletion'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConsentItem(
    BuildContext context,
    String text,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
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
          duration: Duration(seconds: AppConstants.snackbarDurationSeconds),
        ),
      );

      // Load the questions CSV from assets (declared in pubspec)
      final csvContent = await rootBundle.loadString(
        AppConstants.evaluationDatasetPath,
      );

      // Prepare output path - only needed for non-web platforms
      String? outputCsv;
      if (!kIsWeb) {
        final appSupport = await getApplicationSupportDirectory();
        // Build path string - directory creation will be handled by IO implementation
        outputCsv =
            '${appSupport.path}/${AppConstants.evaluationResultsDir}/${AppConstants.evaluationResultsFilename}';
      }

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
      String resultPath;
      try {
        resultPath = await runLLMExperimentFromCsvString(
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
          content: Text(
            kIsWeb
                ? 'Experiment completed. Results downloaded as $resultPath'
                : 'Experiment completed. Results saved to $resultPath',
          ),
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
