import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/chat_message.dart';
import '../widgets/chat_input.dart';
import '../widgets/model_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/edit_profile_dialog.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  bool _isAdmin(User? user) {
    if (user == null) return false;
    final email = user.email ?? '';
    const allowedDomain = '@gmail.com';
    const allowedUids = 'aqela.af@gmail.com';{
      // Add specific admin UIDs here if needed
    }
    return allowedUids.contains(user.uid) || email.endsWith(allowedDomain);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.medical_services,
              color: colorScheme.onSurface,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'MedicoAI',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final isAdmin = _isAdmin(snapshot.data);
              if (!isAdmin) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Admin Logs',
                icon: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/logs');
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Edit Profile',
            icon: Icon(
              Icons.person_outline,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const EditProfileDialog(),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(
              Icons.settings_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            tooltip: 'About',
            icon: Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'About MedicoAI',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: Text(
                    'MedicoAI is an offline medical chatbot that provides general health information. '
                    'Please note that this is not a substitute for professional medical advice.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: Icon(Icons.logout, color: colorScheme.error),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
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
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.psychology_outlined,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No AI Model Loaded',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a model to start chatting',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: colorScheme.surface,
                                  surfaceTintColor: colorScheme.surfaceTint,
                                  child: const SingleChildScrollView(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: ModelSelector(),
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Select Model'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (appState.chatHistory.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Start a conversation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type a message below to begin chatting with MedicoAI',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
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
