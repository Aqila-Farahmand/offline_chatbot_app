import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_manager.dart';
import '../services/app_state.dart';

class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key});

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final models = modelManager.availableModels;
        final selectedModel = modelManager.selectedModel;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick a model',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (models.isNotEmpty)
              DropdownButton<String>(
                isExpanded: true,
                value: selectedModel?.filename,
                hint: const Text('Select a model'),
                items: models.map((model) {
                  return DropdownMenuItem<String>(
                    value: model.filename,
                    child: Text(model.name),
                  );
                }).toList(),
                onChanged: (filename) async {
                  if (filename != null) {
                    final selected = models.firstWhere(
                      (m) => m.filename == filename,
                    );
                    modelManager.selectModel(selected);
                    final appState = Provider.of<AppState>(
                      context,
                      listen: false,
                    );
                    await appState.reinitializeModel();
                    if (!context.mounted) return;
                    Navigator.of(context).pop(); // Close dialog and return to chat
                  }
                },
              )
            else ...[
              const Text(
                'No bundled models found.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}
