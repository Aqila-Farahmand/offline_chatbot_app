import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Privacy service for managing user consent and data collection preferences
///
/// This service handles:
/// - User consent for remote chat history logging (research purposes)
/// - Privacy settings persistence
/// - Data deletion requests
class PrivacyService {
  static const String _keyRemoteLoggingEnabled =
      'privacy_remote_logging_enabled';
  static const String _keyConsentGiven = 'privacy_consent_given';
  static const String _keyConsentDate = 'privacy_consent_date';
  static const String _keyPrivacyNoticeShown = 'privacy_notice_shown';

  /// Check if user has given consent for remote logging
  static Future<bool> hasConsentForRemoteLogging() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyConsentGiven) ?? false;
    } catch (e) {
      print('PrivacyService: Error checking consent: $e');
      return false; // Default to no consent for privacy
    }
  }

  /// Check if remote logging is currently enabled
  static Future<bool> isRemoteLoggingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Must have both consent AND explicit enablement
      final hasConsent = prefs.getBool(_keyConsentGiven) ?? false;
      final isEnabled = prefs.getBool(_keyRemoteLoggingEnabled) ?? false;
      return hasConsent && isEnabled;
    } catch (e) {
      print('PrivacyService: Error checking remote logging status: $e');
      return false; // Default to disabled for privacy
    }
  }

  /// Set user consent for remote logging
  static Future<void> setConsentForRemoteLogging(bool consent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyConsentGiven, consent);
      await prefs.setBool(_keyRemoteLoggingEnabled, consent);
      if (consent) {
        await prefs.setString(
          _keyConsentDate,
          DateTime.now().toUtc().toIso8601String(),
        );
      } else {
        // Remove consent date if consent is withdrawn
        await prefs.remove(_keyConsentDate);
      }
    } catch (e) {
      print('PrivacyService: Error setting consent: $e');
    }
  }

  /// Enable or disable remote logging (requires prior consent)
  static Future<void> setRemoteLoggingEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConsent = prefs.getBool(_keyConsentGiven) ?? false;
      if (!hasConsent && enabled) {
        // Cannot enable without consent
        print('PrivacyService: Cannot enable remote logging without consent');
        return;
      }
      await prefs.setBool(_keyRemoteLoggingEnabled, enabled);
    } catch (e) {
      print('PrivacyService: Error setting remote logging: $e');
    }
  }

  /// Check if privacy notice has been shown to user
  static Future<bool> hasSeenPrivacyNotice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyPrivacyNoticeShown) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark privacy notice as shown
  static Future<void> markPrivacyNoticeShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPrivacyNoticeShown, true);
    } catch (e) {
      print('PrivacyService: Error marking notice as shown: $e');
    }
  }

  /// Get consent date (when user gave consent)
  static Future<String?> getConsentDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyConsentDate);
    } catch (e) {
      return null;
    }
  }

  /// Request deletion of user's chat history from Firestore
  ///
  /// This allows users to delete their data as per privacy regulations.
  /// Note: This requires admin implementation or user self-service deletion.
  static Future<bool> requestDataDeletion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('PrivacyService: No authenticated user for data deletion');
        return false;
      }

      // Disable remote logging immediately
      await setRemoteLoggingEnabled(false);
      await setConsentForRemoteLogging(false);

      // Note: Actual deletion from Firestore would require:
      // 1. Admin action via Firestore console, OR
      // 2. Cloud Function to handle deletion, OR
      // 3. User self-service deletion (if rules allow)

      // For now, we stop logging and inform user
      print(
        'PrivacyService: Remote logging disabled. Contact admin for data deletion.',
      );
      return true;
    } catch (e) {
      print('PrivacyService: Error requesting data deletion: $e');
      return false;
    }
  }

  /// Reset all privacy preferences (for testing or account deletion)
  static Future<void> resetPrivacyPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRemoteLoggingEnabled);
      await prefs.remove(_keyConsentGiven);
      await prefs.remove(_keyConsentDate);
      await prefs.remove(_keyPrivacyNoticeShown);
    } catch (e) {
      print('PrivacyService: Error resetting preferences: $e');
    }
  }
}
