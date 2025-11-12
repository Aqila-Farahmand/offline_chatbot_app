import 'package:firebase_auth/firebase_auth.dart';
import 'app_constants.dart';
import 'admin_config.dart';

/// Firebase-specific configuration constants
///
/// This file contains Firebase-related constants and helper functions.
class FirebaseConfig {
  FirebaseConfig._(); // Private constructor to prevent instantiation

  // ============================================================================
  // Authentication Persistence
  // ============================================================================
  /// Use session-only persistence for localhost/emulator environments
  static const Persistence emulatorAuthPersistence = Persistence.SESSION;

  // ============================================================================
  // Admin Helper Functions
  // ============================================================================
  /// Check if a user is an admin based on email or UID
  ///
  /// This function should be kept in sync with the `isAdmin()` function
  /// in `firestore.rules`. When updating admin emails/UIDs, update both:
  /// 1. `lib/config/admin_config.dart`
  /// 2. `firestore.rules` (the `isAdmin()` function)
  static bool isAdmin(User? user) {
    if (user == null) return false;

    final email = user.email ?? '';
    return AdminConfig.adminEmails.contains(email) ||
        AdminConfig.adminUids.contains(user.uid);
  }

  // ============================================================================
  // Emulator Detection
  // ============================================================================
  /// Check if the app is running in an emulator environment
  ///
  /// Returns true if the hostname matches localhost patterns
  static bool isEmulatorEnvironment(String hostname) {
    return AppConstants.localhostHostnames.contains(hostname);
  }

  // ============================================================================
  // Firestore Collection References
  // ============================================================================
  /// Get the users collection reference
  ///
  /// Usage: `FirebaseFirestore.instance.collection(FirebaseConfig.usersCollection)`
  static String get usersCollection => AppConstants.firestoreCollectionUsers;

  /// Get the chat_logs collection reference
  ///
  /// Usage: `FirebaseFirestore.instance.collection(FirebaseConfig.chatLogsCollection)`
  static String get chatLogsCollection =>
      AppConstants.firestoreCollectionChatLogs;

  /// Get the admin_logs collection reference
  ///
  /// Usage: `FirebaseFirestore.instance.collection(FirebaseConfig.adminLogsCollection)`
  static String get adminLogsCollection =>
      AppConstants.firestoreCollectionAdminLogs;
}
