import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool _isModelLoaded = false;
  String _currentMessage = '';
  List<Map<String, String>> _chatHistory = [];

  bool get isModelLoaded => _isModelLoaded;
  String get currentMessage => _currentMessage;
  List<Map<String, String>> get chatHistory => _chatHistory;

  void setModelLoaded(bool value) {
    _isModelLoaded = value;
    notifyListeners();
  }

  void setCurrentMessage(String message) {
    _currentMessage = message;
    notifyListeners();
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
}
