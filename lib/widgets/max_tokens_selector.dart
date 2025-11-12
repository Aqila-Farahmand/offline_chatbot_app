import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/llm_service_web.dart' as web;
import '../config/llm_config.dart';

class MaxTokensSelector extends StatefulWidget {
  const MaxTokensSelector({super.key});

  @override
  State<MaxTokensSelector> createState() => _MaxTokensSelectorState();
}

class _MaxTokensSelectorState extends State<MaxTokensSelector> {
  int _currentMaxTokens = LLMConfig.defaultMaxTokens;
  bool _isLoading = false;

  // Common max token values for different model sizes (from LLMConfig)
  final List<int> _maxTokenOptions = [
    LLMConfig.maxTokensSmall,
    LLMConfig.maxTokensMedium,
    LLMConfig.maxTokensLarge,
    LLMConfig.maxTokensVeryLarge,
    LLMConfig.maxTokensExtreme,
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
      // Update the max tokens setting
      web.LLMService.setMaxTokens(newValue);
      _currentMaxTokens = newValue;

      if (kDebugMode) {
        print('Max tokens updated to: $newValue');
      }

      // Note: The service needs to be reinitialized for the change to take effect
      // This is because maxTokens is set during initialization
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Max tokens set to $newValue. The model will be reinitialized with the new setting.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
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
                  'Current setting: $_currentMaxTokens tokens. The model will use this limit for token management and history truncation.',
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
