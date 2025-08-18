import 'dart:io';
import 'package:flutter/services.dart';

class MediapipeAndroidService {
  static const MethodChannel _channel = MethodChannel('mediapipe_llm');
  static bool _initialized = false;

  static Future<void> initialize(String modelPath) async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;
    final ok = await _channel.invokeMethod<bool>('init', {
      'modelPath': modelPath,
    });
    if (ok != true) {
      throw Exception('Failed to initialize MediaPipe LLM');
    }
    _initialized = true;
  }

  static Future<String> generate(String prompt) async {
    if (!Platform.isAndroid) {
      throw Exception('MediapipeAndroidService only available on Android');
    }
    final result = await _channel.invokeMethod<String>('generate', {
      'prompt': prompt,
    });
    if (result == null) {
      throw Exception('Null result from MediaPipe generation');
    }
    return result;
  }

  static Future<void> dispose() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('dispose');
    } finally {
      _initialized = false;
    }
  }
}


