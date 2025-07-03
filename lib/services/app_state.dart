import 'package:flutter/foundation.dart';
import 'llm_service.dart';

class AppState extends ChangeNotifier {
  bool _isModelLoaded = false;
  String _currentMessage = '';
  List<Map<String, String>> _chatHistory = [];
  bool _isProcessing = false;

  bool get isModelLoaded => _isModelLoaded;
  String get currentMessage => _currentMessage;
  List<Map<String, String>> get chatHistory => _chatHistory;
  bool get isProcessing => _isProcessing;

  AppState() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      await LLMService.initialize();
      setModelLoaded(true);
    } catch (e) {
      print('Error initializing model: $e');
      setModelLoaded(false);
    }
  }

  void setModelLoaded(bool value) {
    _isModelLoaded = value;
    notifyListeners();
  }

  void setCurrentMessage(String message) {
    _currentMessage = message;
    notifyListeners();
  }

  Future<void> sendMessage(String message) async {
    if (!_isModelLoaded || message.trim().isEmpty || _isProcessing) return;

    try {
      _isProcessing = true;
      notifyListeners();

      // Add user message to chat
      addMessageToHistory(message, true);

      // Generate response using local LLM
      final response = await LLMService.generateResponse(message);

      // Add bot response to chat
      addMessageToHistory(response, false);
    } catch (e) {
      print('Error generating response: $e');
      addMessageToHistory(
        'Sorry, I encountered an error. Please try again.',
        false,
      );
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void addMessageToHistory(String message, bool isUser) {
    _chatHistory.add({
      'message': message,
      'type': isUser ? 'user' : 'bot',
      'timestamp': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  void clearHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    LLMService.dispose();
    super.dispose();
  }
}
