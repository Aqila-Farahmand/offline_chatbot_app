/// Core application constants
///
/// This file contains all core constants used throughout the application.
/// These values should be used instead of hardcoded strings/numbers.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // ============================================================================
  // Firestore Collection Names
  // ============================================================================
  /// Firestore collection name for user profiles
  static const String firestoreCollectionUsers = 'users';

  /// Firestore collection name for chat logs
  static const String firestoreCollectionChatLogs = 'chat_logs';

  /// Firestore collection name for admin logs
  static const String firestoreCollectionAdminLogs = 'admin_logs';

  // ============================================================================
  // Timeout Durations
  // ============================================================================
  /// Timeout for Firebase initialization (seconds)
  static const int firebaseInitTimeoutSeconds = 10;

  /// Timeout for Firestore operations (seconds)
  static const int firestoreOperationTimeoutSeconds = 10;

  /// Timeout for chat history logging (seconds)
  static const int chatHistoryLogTimeoutSeconds = 5;

  /// Timeout for model downloads (minutes)
  static const int modelDownloadTimeoutMinutes = 30;

  /// Timeout for LLM service operations (milliseconds)
  static const int llmServiceMaxWaitMs = 10000;

  /// Splash screen display duration (seconds)
  static const int splashScreenDurationSeconds = 2;

  /// Snackbar display duration (seconds)
  static const int snackbarDurationSeconds = 5;

  // ============================================================================
  // Firebase Emulator Configuration
  // ============================================================================
  /// Default Firestore emulator host
  static const String firestoreEmulatorHost = '127.0.0.1';

  /// Default Firestore emulator port
  static const int firestoreEmulatorPort = 8080;

  /// Localhost hostnames for emulator detection
  static const List<String> localhostHostnames = ['127.0.0.1', 'localhost'];

  // ============================================================================
  // Application Metadata
  // ============================================================================
  /// Application name
  static const String appName = 'MedicoAI';

  /// Application title
  static const String appTitle = 'MedicoAI';

  // ============================================================================
  // File Paths & Directories
  // ============================================================================
  /// Evaluation dataset path (relative to assets)
  static const String evaluationDatasetPath =
      'evaluation/dataset/questions.csv';

  /// Evaluation results directory name
  static const String evaluationResultsDir = 'evaluation/results';

  /// Evaluation results filename
  static const String evaluationResultsFilename = 'questions_experiment.csv';

  /// Chat logs directory name (for local storage)
  static const String chatLogsDir = 'chat_logs';

  /// Models directory name
  static const String modelsDir = 'models';

  // ============================================================================
  // Query Limits
  // ============================================================================
  /// Maximum number of chat logs to retrieve in admin view
  static const int maxChatLogsQueryLimit = 1000;
}
