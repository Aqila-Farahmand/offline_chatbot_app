@JS()
library;

// Web implementation using JS bridge defined in web/mediapipe_text.js
import 'dart:async';
import 'dart:js_interop';
import 'model_manager.dart';

@JS('MediapipeGenai')
external MediapipeGenai? get _mediapipeGenai;

@JS()
extension type MediapipeGenai(JSObject o) implements JSObject {
  external JSPromise init(InitOptions options);
  external JSPromise generate(String prompt);
  external void dispose();
}

@JS()
extension type InitOptions._(JSObject o) implements JSObject {
  external factory InitOptions({
    String modelAssetPath,
    String tasksModulePath,
    String wasmBasePath,
  });
}

class LLMService {
  static bool _isInitialized = false;
  static final ModelManager _modelManager = ModelManager();
  static String? _modelAssetPath; // e.g. assets/models/xxx.task

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Ensure model manager is initialized and a model is selected
    await _modelManager.initialize();
    _modelAssetPath = await _modelManager.getSelectedModelPath();
    if (_modelAssetPath == null) {
      throw Exception('No model selected');
    }

    // Call MediapipeGenai.init with local asset paths
    final mp = _mediapipeGenai;
    if (mp == null) {
      throw Exception(
        'MediapipeGenai JS bridge not found. Ensure mediapipe_text.js is loaded in index.html',
      );
    }

    final options = InitOptions(
      modelAssetPath: _modelAssetPath!,
      tasksModulePath: '/assets/mediapipe/genai_bundle.mjs',
      wasmBasePath: '/assets/mediapipe/wasm',
    );

    await mp.init(options).toDart;
    _isInitialized = true;
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      throw Exception('LLM not initialized. Please initialize first.');
    }
    final mp = _mediapipeGenai;
    if (mp == null) {
      throw Exception('MediapipeGenai JS bridge not found.');
    }
    final result = await mp.generate(prompt).toDart;
    return result?.toString() ?? '';
  }

  static void dispose() {
    final mp = _mediapipeGenai;
    if (mp != null) {
      try {
        mp.dispose();
      } catch (_) {}
    }
    _isInitialized = false;
    _modelAssetPath = null;
  }
}
