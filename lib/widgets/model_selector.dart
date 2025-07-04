import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/model_manager.dart';
import '../services/llm_service.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

  Future<void> _pickAndAddModel(
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
            ).showSnackBar(const SnackBar(content: Text('Adding model...')));
          }

          // Add the model
          await modelManager.addModel(file.path!);

          // Reinitialize LLM service with new model
          await LLMService.initialize();

          // Show success message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Model added successfully')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding model: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final models = modelManager.availableModels;
        final selectedModel = modelManager.selectedModel;

        if (models.isEmpty) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'No models available. Please add a model to continue.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _pickAndAddModel(context, modelManager),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Model'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Model',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedModel?.filename,
                  isExpanded: true,
                  hint: const Text('Select a model'),
                  items: models.map((model) {
                    return DropdownMenuItem(
                      value: model.filename,
                      child: Text(model.name),
                    );
                  }).toList(),
                  onChanged: (filename) async {
                    if (filename != null) {
                      final model = models.firstWhere(
                        (m) => m.filename == filename,
                      );
                      modelManager.selectModel(model);

                      // Reinitialize LLM service with new model
                      await LLMService.initialize();
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _pickAndAddModel(context, modelManager),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Model'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
