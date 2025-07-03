import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:process_run/process_run.dart';

class LLMService {
  static const String MODEL_FILENAME = 'medllama2.gguf';
  static bool _isInitialized = false;
  static String? _modelPath;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _modelPath = await _getModelPath();
      if (!await File(_modelPath!).exists()) {
        await _downloadModel(_modelPath!);
      }
      
      _isInitialized = true;
    } catch (e) {
      print('Error initializing LLM: $e');
      rethrow;
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_isInitialized || _modelPath == null) {
      throw Exception('LLM not initialized');
    }

    try {
      // Format the prompt for medical context
      final formattedPrompt = '''
System: You are a medical AI assistant. Provide accurate, helpful medical information while clearly stating that you are not a substitute for professional medical advice.

User: $prompt