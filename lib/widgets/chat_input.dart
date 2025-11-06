import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isComposing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _isComposing = false;
    });

    final appState = context.read<AppState>();
    appState.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isProcessing = context.watch<AppState>().isProcessing;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: !isProcessing,
                    onChanged: (text) {
                      setState(() {
                        _isComposing = text.isNotEmpty;
                      });
                    },
                    onSubmitted: _isComposing && !isProcessing
                        ? _handleSubmitted
                        : null,
                    decoration: InputDecoration(
                      hintText: isProcessing
                          ? 'Processing...'
                          : 'Type your message...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      suffixIcon: _isComposing && !isProcessing
                          ? IconButton(
                              icon: Icon(
                                Icons.send,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _handleSubmitted(_controller.text),
                              tooltip: 'Send message',
                            )
                          : isProcessing
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
