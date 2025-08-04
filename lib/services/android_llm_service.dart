import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

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
      print('Android LLM service already initialized');
      return;
    }

    try {
      print('Loading Android native library...');
      
      // Load the native library
      _lib = Platform.isAndroid
          ? DynamicLibrary.open('libllama_native.so')
          : null;

      if (_lib == null) {
        throw Exception('Failed to load native library');
      }

      // Look up the functions
      _initLlama = _lib!.lookupFunction<InitLlamaFunc, InitLlama>('initLlama');
      _generateText = _lib!.lookupFunction<GenerateTextFunc, GenerateText>('generateText');
      _freeLlama = _lib!.lookupFunction<FreeLlamaFunc, FreeLlama>('freeLlama');

      if (_initLlama == null || _generateText == null || _freeLlama == null) {
        throw Exception('Failed to lookup native functions');
      }

      _isInitialized = true;
      print('Android LLM service initialized successfully');
    } catch (e) {
      print('Error initializing Android LLM service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<bool> initLlama(String modelPath) async {
    if (!_isInitialized || _initLlama == null) {
      throw Exception('Android LLM service not initialized');
    }

    try {
      print('Initializing llama with model: $modelPath');
      
      final modelPathPtr = modelPath.toNativeUtf8();
      final result = _initLlama!(modelPathPtr);
      
      calloc.free(modelPathPtr);
      
      if (result) {
        print('Llama initialized successfully');
      } else {
        print('Failed to initialize llama');
      }
      
      return result;
    } catch (e) {
      print('Error initializing llama: $e');
      return false;
    }
  }

  Future<String> generateText(String prompt) async {
    if (!_isInitialized || _generateText == null) {
      throw Exception('Android LLM service not initialized');
    }

    try {
      print('Generating text with prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...');
      
      final promptPtr = prompt.toNativeUtf8();
      final resultPtr = _generateText!(promptPtr);
      
      calloc.free(promptPtr);
      
      if (resultPtr == nullptr) {
        throw Exception('Failed to generate text');
      }
      
      final result = resultPtr.toDartString();
      calloc.free(resultPtr);
      
      print('Text generation completed');
      return result;
    } catch (e) {
      print('Error generating text: $e');
      rethrow;
    }
  }

  void freeLlama() {
    if (_isInitialized && _freeLlama != null) {
      try {
        print('Freeing llama resources...');
        _freeLlama!();
        print('Llama resources freed');
      } catch (e) {
        print('Error freeing llama resources: $e');
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