import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/chat_message.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedicoAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About MedicoAI'),
                  content: const Text(
                    'MedicoAI is an offline medical chatbot that provides general health information. '
                    'Please note that this is not a substitute for professional medical advice.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                if (!appState.isModelLoaded) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading AI Model...'),
                      ],
                    ),
                  );
                }

                if (appState.chatHistory.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start a conversation by typing a message below.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: appState.chatHistory.length,
                  itemBuilder: (context, index) {
                    final message = appState
                        .chatHistory[appState.chatHistory.length - 1 - index];
                    return ChatMessage(
                      message: message['message']!,
                      isUser: message['type'] == 'user',
                    );
                  },
                );
              },
            ),
          ),
          const ChatInput(),
        ],
      ),
    );
  }
}
