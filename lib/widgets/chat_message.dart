import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMessage extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatMessage({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(context),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      message,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: message,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: colorScheme.onSurface,
                          height: 1.4,
                          fontSize: 16,
                        ),
                        listBullet: TextStyle(color: colorScheme.onSurface),
                        code: TextStyle(
                          color: colorScheme.onSurface,
                          backgroundColor: colorScheme.surfaceContainerLowest
                              .withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest.withValues(
                            alpha: 0.3,
                          ),
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                              width: 4,
                            ),
                          ),
                        ),
                        h1: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        h2: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        h3: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          if (isUser) _buildAvatar(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? colorScheme.primary : colorScheme.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person : Icons.medical_services,
        color: isUser ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
        size: 18,
      ),
    );
  }
}
