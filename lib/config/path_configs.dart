// This file contains all static paths for assets and models.

class AppPaths {
  // Base model directory (Flutter adds 'assets/' prefix automatically)
  static const String modelPaths = 'models/';

  // Full path to the web app local model .task model file
  static const String gemma3WebModel =
      '${modelPaths}gemma3-1b-it-int8-web.task';

  // MediaPipe paths (Flutter adds 'assets/' prefix automatically)
  static const String tasksModulePath = '/assets/mediapipe/genai_bundle.mjs';
  static const String wasmBasePath = '/assets/mediapipe/wasm/';
}
