import 'package:flutter/foundation.dart';

/// Environment configuration
///
/// This file manages environment-specific configurations.
/// Use [EnvironmentConfig.current] to access the current environment settings.
class EnvironmentConfig {
  EnvironmentConfig._(); // Private constructor to prevent instantiation

  /// Current environment (determined at runtime)
  static Environment get current {
    if (kDebugMode) {
      // In debug mode, check if we're using emulators
      // This can be overridden by environment variables if needed
      return Environment.development;
    }
    // In release mode, assume production
    return Environment.production;
  }

  /// Check if running in development mode
  static bool get isDevelopment => current == Environment.development;

  /// Check if running in production mode
  static bool get isProduction => current == Environment.production;

  /// Get the appropriate timeout multiplier for the current environment
  ///
  /// Development environments may use longer timeouts for debugging
  static double get timeoutMultiplier {
    switch (current) {
      case Environment.development:
        return 1.5; // 50% longer timeouts in dev
      case Environment.production:
        return 1.0; // Normal timeouts in production
    }
  }

  /// Get the appropriate log level for the current environment
  static LogLevel get logLevel {
    switch (current) {
      case Environment.development:
        return LogLevel.debug;
      case Environment.production:
        return LogLevel.warning; // Only warnings and errors in production
    }
  }
}

/// Environment types
enum Environment {
  /// Development environment (debug builds, emulators)
  development,

  /// Production environment (release builds)
  production,
}

/// Log levels for different environments
enum LogLevel {
  /// Show all logs (debug, info, warning, error)
  debug,

  /// Show only warnings and errors
  warning,

  /// Show only errors
  error,
}
