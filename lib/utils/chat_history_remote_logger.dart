import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ChatHistoryRemoteLogger {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static String _getPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'web';
    }
  }

  static Future<void> logModelEvalRemote({
    required String modelName,
    required String userQuestion,
    required String modelResponse,
    required int responseTimeMs,
    required String promptLabel,
    String? timestampIso,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('ChatHistoryRemoteLogger: No authenticated user.');
        return;
      }

      final ts = timestampIso ?? DateTime.now().toUtc().toIso8601String();

      // Add timeout to prevent blocking when offline
      await _db
          .collection('chat_logs')
          .add({
            'timestamp_iso': ts,
            'uid': user.uid,
            'model_name': modelName,
            'prompt_label': promptLabel,
            'question': userQuestion,
            'response': modelResponse,
            'response_time_ms': responseTimeMs,
            'platform': _getPlatform(),
          })
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print(
                'ChatHistoryRemoteLogger: Timeout - offline or network issue',
              );
              throw TimeoutException(
                'Firestore write timeout',
                const Duration(seconds: 5),
              );
            },
          );
    } on TimeoutException {
      // Silently handle timeout - app should work offline
      print('ChatHistoryRemoteLogger: Operation timed out (offline mode)');
    } catch (e) {
      // Log but don't throw - app should continue working offline
      print('ChatHistoryRemoteLogger error: $e');
    }
  }
}
