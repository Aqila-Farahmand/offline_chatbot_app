import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import '../config/app_constants.dart';
import '../config/firebase_config.dart';
import '../services/privacy_service.dart';

/// Remote chat history logger that never blocks offline functionality
///
/// This logger uses Firestore's offline persistence to queue writes when offline.
/// All operations are fire-and-forget with timeouts to ensure the app works
/// completely offline. Writes are automatically synced when connection is restored.
class ChatHistoryRemoteLogger {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // Track if we've enabled offline persistence (one-time setup)
  static bool _offlinePersistenceEnabled = false;

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

  /// Enable Firestore offline persistence for automatic queuing
  ///
  /// This should be called once during app initialization to enable
  /// offline persistence. Writes will be queued when offline and
  /// automatically synced when connection is restored.
  static Future<void> enableOfflinePersistence() async {
    if (_offlinePersistenceEnabled) return;

    try {
      // Firestore automatically enables offline persistence on web
      // For native platforms, it's enabled by default
      // This is a no-op but documents the intent
      _offlinePersistenceEnabled = true;
      if (kDebugMode) {
        print('ChatHistoryRemoteLogger: Offline persistence enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'ChatHistoryRemoteLogger: Error enabling offline persistence: $e',
        );
      }
      // Don't throw - app should work even if persistence setup fails
    }
  }

  /// Logs a model evaluation to Firestore (non-blocking, offline-safe)
  ///
  /// **PRIVACY NOTE**: This only logs if user has given explicit consent.
  /// Data is collected for research purposes only (prototype app).
  ///
  /// This method:
  /// - Checks user consent before logging (privacy-first)
  /// - Never blocks the UI (fire-and-forget)
  /// - Times out quickly if offline (5 seconds)
  /// - Uses Firestore offline persistence to queue writes
  /// - Silently handles all errors
  ///
  /// When offline, Firestore will:
  /// - Queue the write locally
  /// - Automatically sync when connection is restored
  /// - No user action required
  static Future<void> logModelEvalRemote({
    required String modelName,
    required String userQuestion,
    required String modelResponse,
    required int responseTimeMs,
    required String promptLabel,
    String? timestampIso,
  }) async {
    // PRIVACY CHECK: Only log if user has given explicit consent
    try {
      final hasConsent = await PrivacyService.isRemoteLoggingEnabled();
      if (!hasConsent) {
        // User has not consented or has disabled remote logging
        // Silently skip logging - this is expected behavior
        if (kDebugMode) {
          print(
            'ChatHistoryRemoteLogger: Remote logging disabled by user (privacy setting).',
          );
        }
        return;
      }
    } catch (e) {
      // If we can't check consent, default to NOT logging (privacy-first)
      if (kDebugMode) {
        print(
          'ChatHistoryRemoteLogger: Error checking consent, skipping log: $e',
        );
      }
      return;
    }

    // Ensure offline persistence is enabled
    if (!_offlinePersistenceEnabled) {
      await enableOfflinePersistence();
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('ChatHistoryRemoteLogger: No authenticated user.');
        }
        return;
      }

      final ts = timestampIso ?? DateTime.now().toUtc().toIso8601String();

      // Use Firestore's offline persistence - writes are queued when offline
      // and automatically synced when connection is restored
      // The timeout is just a safety measure, Firestore handles offline gracefully
      await _db
          .collection(FirebaseConfig.chatLogsCollection)
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
            Duration(seconds: AppConstants.chatHistoryLogTimeoutSeconds),
            onTimeout: () {
              // Timeout doesn't mean failure - Firestore will queue the write
              // when offline and sync later
              if (kDebugMode) {
                print(
                  'ChatHistoryRemoteLogger: Write timeout (likely offline). '
                  'Firestore will queue and sync when online.',
                );
              }
              throw TimeoutException(
                'Firestore write timeout',
                Duration(seconds: AppConstants.chatHistoryLogTimeoutSeconds),
              );
            },
          );

      if (kDebugMode) {
        print('ChatHistoryRemoteLogger: Successfully logged to Firestore');
      }
    } on TimeoutException {
      // Timeout is expected when offline - Firestore queues the write
      // No action needed, it will sync automatically when online
      if (kDebugMode) {
        print(
          'ChatHistoryRemoteLogger: Write timed out (offline mode). '
          'Queued for sync when connection restored.',
        );
      }
    } catch (e) {
      // All other errors are caught and logged, never thrown
      // This ensures the app continues working offline
      if (kDebugMode) {
        print('ChatHistoryRemoteLogger error (non-blocking): $e');
      }
    }
  }
}
