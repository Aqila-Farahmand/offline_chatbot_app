import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatHistoryRemoteLogger {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<void> logModelEvalRemote({
    required String modelName,
    required String userQuestion,
    required String modelResponse,
    required int responseTimeMs,
    String promptLabel = 'default',
    String? timestampIso,
  }) async {
    try {
      final user = _auth.currentUser;
      final ts = timestampIso ?? DateTime.now().toUtc().toIso8601String();
      await _db.collection('chat_logs').add({
        'timestamp_iso': ts,
        'uid': user?.uid,
        'model_name': modelName,
        'prompt_label': promptLabel,
        'question': userQuestion,
        'response': modelResponse,
        'response_time_ms': responseTimeMs,
        'platform': 'flutter',
      });
    } catch (e) {
      // ignore: avoid_print
      print('ChatHistoryRemoteLogger error: $e');
    }
  }
}
