import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/model_manager.dart';
//import '../services/llm_service.dart';
import '../services/app_state.dart';
import '../services/model_downloader.dart';

class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key});

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  String? _downloadingModel;
  double _downloadProgress = 0.0;

  Future<void> _importLocalModel(
    BuildContext context,
    ModelManager modelManager,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          // Show loading indicator
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Importing model...')));
          }

          // Add the model
          await modelManager.addModel(file.path!);

          // Get AppState to reinitialize
          if (context.mounted) {
            final appState = Provider.of<AppState>(context, listen: false);
            await appState.reinitializeModel();
          }

          // Show success message and close dialog
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Model imported successfully')),
            );
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error importing model: $e')));
      }
    }
  }

  Future<void> _downloadModel(BuildContext context, String modelId) async {
    setState(() {
      _downloadingModel = modelId;
      _downloadProgress = 0.0;
    });

    try {
      await ModelDownloader.downloadModel(
        modelId: modelId,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        onComplete: () async {
          setState(() {
            _downloadingModel = null;
          });

          // Get AppState to reinitialize
          if (context.mounted) {
            final appState = Provider.of<AppState>(context, listen: false);
            await appState.reinitializeModel();
          }

          // Show success message and close dialog
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Model downloaded successfully')),
            );
            Navigator.pop(context);
          }
        },
        onError: (error) {
          setState(() {
            _downloadingModel = null;
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error downloading model: $error')),
            );
          }
        },
      );
    } catch (e) {
      setState(() {
        _downloadingModel = null;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading model: $e')));
      }
    }
  }

  void _showDownloadOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Models:'),
            const SizedBox(height: 8),
            ...ModelDownloader.availableModels.entries.map((entry) {
              final modelId = entry.key;
              final model = entry.value;
              final isDownloading = _downloadingModel == modelId;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(model.name),
                        subtitle: Text(
                          '${model.description}\nSize: ${model.formattedSize}',
                        ),
                        trailing: isDownloading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () =>
                                    _downloadModel(context, modelId),
                              ),
                      ),
                      if (isDownloading)
                        LinearProgressIndicator(value: _downloadProgress),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Note: Model download requires a stable internet connection and sufficient storage space.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final models = modelManager.availableModels;
        final selectedModel = modelManager.selectedModel;

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Model Selection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (models.isNotEmpty) ...[
                  const Text(
                    'Local Models',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      return RadioListTile<String>(
                        title: Text(model.name),
                        subtitle: Text(model.filename),
                        value: model.filename,
                        groupValue: selectedModel?.filename,
                        onChanged: (filename) async {
                          if (filename != null) {
                            final selectedModel = models.firstWhere(
                              (m) => m.filename == filename,
                            );
                            modelManager.selectModel(selectedModel);

                            // Get AppState to reinitialize
                            final appState = Provider.of<AppState>(
                              context,
                              listen: false,
                            );
                            await appState.reinitializeModel();

                            // Close dialog
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                      );
                    },
                  ),
                  const Divider(),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _importLocalModel(context, modelManager),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Import Local Model'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDownloadOptions(context),
                        icon: const Icon(Icons.download),
                        label: const Text('Download New Model'),
                      ),
                    ),
                  ],
                ),
                if (models.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'No models available locally. Please import a model or download one to continue.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
