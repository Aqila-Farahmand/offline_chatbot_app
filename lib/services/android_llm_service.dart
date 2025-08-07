import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// FFI function signatures for llama.cpp
typedef InitLlamaFunc = Bool Function(Pointer<Utf8>);
typedef GenerateTextFunc = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FreeLlamaFunc = Void Function();

// Dart function signatures
typedef InitLlama = bool Function(Pointer<Utf8>);
typedef GenerateText = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FreeLlama = void Function();

class AndroidLLMService {
  static DynamicLibrary? _lib;
  static InitLlama? _initLlama;
  static GenerateText? _generateText;
  static FreeLlama? _freeLlama;
  static bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Android LLM service already initialized');
      return;
    }

    try {
      debugPrint('Loading Android native library...');
      
      // Load the native library
      _lib = Platform.isAndroid
          ? DynamicLibrary.open('libllama_native.so')
          : null;

      if (_lib == null) {
        throw Exception('Failed to load native library');
      }

      debugPrint('Native library loaded successfully');

      // Look up the functions
      _initLlama = _lib!.lookupFunction<InitLlamaFunc, InitLlama>('initLlama');
      _generateText = _lib!.lookupFunction<GenerateTextFunc, GenerateText>('generateText');
      _freeLlama = _lib!.lookupFunction<FreeLlamaFunc, FreeLlama>('freeLlama');

      if (_initLlama == null || _generateText == null || _freeLlama == null) {
        throw Exception('Failed to lookup native functions');
      }

      debugPrint('All native functions found successfully');
      debugPrint('Android LLM service initialized successfully');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Android LLM service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<bool> initLlama(String modelPath) async {
    if (!_isInitialized || _initLlama == null) {
      throw Exception('Android LLM service not initialized');
    }

    try {
      debugPrint('Initializing llama with model: $modelPath');
      
      // Check if file exists
      final file = File(modelPath);
      if (!await file.exists()) {
        debugPrint('Model file does not exist: $modelPath');
        return false;
      }
      
      final modelPathPtr = modelPath.toNativeUtf8();
      debugPrint('Calling native initLlama function...');
      
      final result = _initLlama!(modelPathPtr);
      
      calloc.free(modelPathPtr);
      
      if (result) {
        debugPrint('Llama initialized successfully');
      } else {
        debugPrint('Failed to initialize llama - native function returned false');
      }
      
      return result;
    } catch (e) {
      debugPrint('Error initializing llama: $e');
      return false;
    }
  }

  // Simple test function to check if native library is working
  Future<String> testNativeLibrary() async {
    if (!_isInitialized || _generateText == null) {
      throw Exception('Android LLM service not initialized');
    }

    try {
      debugPrint('Testing native library with simple prompt...');
      
      final testPrompt = "Hello";
      final promptPtr = testPrompt.toNativeUtf8();
      
      debugPrint('Calling native generateText function with test prompt...');
      
      final resultPtr = _generateText!(promptPtr);
      
      calloc.free(promptPtr);
      
      if (resultPtr == nullptr) {
        return "Test failed: null pointer returned";
      }
      
      final result = resultPtr.toDartString();
      calloc.free(resultPtr);
      
      debugPrint('Test completed successfully');
      return "Test successful: $result";
    } catch (e) {
      debugPrint('Test failed with error: $e');
      return "Test failed: $e";
    }
  }

  Future<String> generateText(String prompt) async {
    if (!_isInitialized || _generateText == null) {
      throw Exception('Android LLM service not initialized');
    }

    try {
      debugPrint('Generating text with prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...');
      debugPrint('Prompt sent to native: $prompt');
      
      final promptPtr = prompt.toNativeUtf8();
      debugPrint('Calling native generateText function...');
      
      // Add timeout protection
      final resultPtr = await Future.delayed(Duration.zero, () {
        return _generateText!(promptPtr);
      }).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          calloc.free(promptPtr);
          throw Exception('Text generation timed out after 30 seconds');
        },
      );
      
      calloc.free(promptPtr);
      
      if (resultPtr == nullptr) {
        throw Exception('Failed to generate text - null pointer returned');
      }
      
      final result = resultPtr.toDartString();
      calloc.free(resultPtr);
      
      debugPrint('Native response: $result');
      debugPrint('Text generation completed successfully');
      return result;
    } catch (e) {
      debugPrint('Error generating text: $e');
      rethrow;
    }
  }

  void freeLlama() {
    if (_isInitialized && _freeLlama != null) {
      try {
        debugPrint('Freeing llama resources...');
        _freeLlama!();
        debugPrint('Llama resources freed');
      } catch (e) {
        debugPrint('Error freeing llama resources: $e');
      }
    }
  }

  void dispose() {
    freeLlama();
    _isInitialized = false;
    _lib = null;
    _initLlama = null;
    _generateText = null;
    _freeLlama = null;
  }
}