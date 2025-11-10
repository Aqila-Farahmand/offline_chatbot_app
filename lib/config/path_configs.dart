// This file contains all static paths for assets and models.

class AppPaths {
  // Base model directory (Flutter adds 'assets/' prefix automatically)
  static const String modelPaths = 'models/';

  // Full path to the web app local model .task model file
  static const String gemma3WebModel =
      '${modelPaths}gemma3-1b-it-int8-web.task';

  // MediaPipe paths - use /assets/ prefix for consistency across all platforms
  // Note: mediapipe/ directory is at project root level, but Flutter copies it to
  // assets/mediapipe/ during build (as specified in pubspec.yaml)
  // Flutter web serves assets from /assets/ in both debug and release modes
  static const String tasksModulePath = '/assets/mediapipe/genai_bundle.mjs';
  static const String wasmBasePath = '/assets/mediapipe/wasm/';
}
