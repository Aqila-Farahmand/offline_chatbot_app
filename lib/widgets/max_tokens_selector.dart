import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/llm_service_web.dart' as web;

class MaxTokensSelector extends StatefulWidget {
  const MaxTokensSelector({super.key});

  @override
  State<MaxTokensSelector> createState() => _MaxTokensSelectorState();
}

class _MaxTokensSelectorState extends State<MaxTokensSelector> {
  int _currentMaxTokens = 1280;
  bool _isLoading = false;

  // Common max token values for different model sizes
  final List<int> _maxTokenOptions = [
    512, // Small models
    1024, // Medium models
    1280, // Default for web
    2048, // Large models
    4096, // Very large models
  ];

  @override
  void initState() {
    super.initState();
    _currentMaxTokens = web.LLMService.maxTokens;
  }

  void _updateMaxTokens(int newValue) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      web.LLMService.setMaxTokens(newValue);
      _currentMaxTokens = newValue;

      if (kDebugMode) {
        print('Max tokens updated to: $newValue');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Max tokens set to $newValue. Restart the app to apply changes.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update max tokens: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Max Tokens',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Maximum number of tokens the model can process. Higher values allow longer conversations but may cause memory issues.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Updating...',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _maxTokenOptions.map((tokens) {
              final isSelected = _currentMaxTokens == tokens;
              return FilterChip(
                label: Text('$tokens'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _updateMaxTokens(tokens);
                  }
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.5),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Current setting: $_currentMaxTokens tokens. Changes require app restart.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
