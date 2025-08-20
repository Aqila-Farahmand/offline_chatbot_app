import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import '../services/model_manager.dart';
import '../services/app_state.dart';
import '../services/model_downloader.dart';

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
            ExpansionTile(
              title: const Text('Download models'),
              initiallyExpanded: true,
              children: [
                // Desktop (.gguf)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Text(
                      'Desktop (.gguf)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                for (final entry in ModelDownloader.availableModels.entries.where((e) => e.value.filename.endsWith('.gguf')))
                  _DownloadTile(
                    modelId: entry.key,
                    info: entry.value,
                    onDownloaded: () async {
                      await modelManager.rescanModels();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloaded ${entry.value.name}')),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                // Android (.task)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Text(
                      'Android (.task)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                for (final entry in ModelDownloader.availableModels.entries.where((e) => e.value.filename.endsWith('.task')))
                  _DownloadTile(
                    modelId: entry.key,
                    info: entry.value,
                    onDownloaded: () async {
                      await modelManager.rescanModels();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloaded ${entry.value.name}')),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                Platform.isAndroid
                    ? 'Tip: On Android, select a .task model (MediaPipe).'
                    : 'Tip: On desktop (macOS/Windows/Linux), select a .gguf model.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            if (models.isNotEmpty)
              DropdownButton<String>(
                isExpanded: true,
                value: selectedModel?.filename,
                hint: const Text('Select a model'),
                items: models.map((model) {
                  return DropdownMenuItem<String>(
                    value: model.filename,
                    child: Text(
                      '${model.name}${model.filename.endsWith('.task') ? ' (.task)' : ' (.gguf)'}',
                    ),
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

class _DownloadTile extends StatefulWidget {
  final String modelId;
  final ModelInfo info;
  final Future<void> Function() onDownloaded;

  const _DownloadTile({
    required this.modelId,
    required this.info,
    required this.onDownloaded,
  });

  @override
  State<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<_DownloadTile> {
  double _progress = 0.0;
  bool _isDownloading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.info.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.info.description,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(widget.info.formattedSize,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Downloading' : 'Download'),
                  onPressed: _isDownloading
                      ? null
                      : () async {
                          setState(() {
                            _isDownloading = true;
                            _progress = 0.0;
                            _error = null;
                          });
                          await ModelDownloader.downloadModel(
                            modelId: widget.modelId,
                            onProgress: (p) => setState(() => _progress = p),
                            onComplete: () async {
                              setState(() => _isDownloading = false);
                              await widget.onDownloaded();
                            },
                            onError: (err) => setState(() {
                              _isDownloading = false;
                              _error = err;
                            }),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isDownloading)
              LinearProgressIndicator(value: _progress.clamp(0.0, 1.0)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
