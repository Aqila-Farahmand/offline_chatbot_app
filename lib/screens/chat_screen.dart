import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/chat_message.dart';
import '../widgets/chat_input.dart';
import '../widgets/model_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/edit_profile_dialog.dart';
import 'dart:io' show Platform;
import '../services/llm_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical AI Assistant'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          // Add test button for debugging
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                try {
                  final result = await LLMService.testAndroidNativeLibrary();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test Result: $result'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test Error: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              tooltip: 'Test Native Library',
            ),
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.person),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const EditProfileDialog(),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('No AI Model Loaded'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const Dialog(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: ModelSelector(),
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Model'),
                        ),
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
