import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_manager.dart';
import '../services/app_state.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

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
                    'Bundled Models',
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

                            final appState = Provider.of<AppState>(
                              context,
                              listen: false,
                            );
                            await appState.reinitializeModel();
                          }
                        },
                      );
                    },
                  ),
                ],
                if (models.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'No bundled models found.',
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
