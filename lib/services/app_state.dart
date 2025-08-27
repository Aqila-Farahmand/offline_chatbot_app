import 'package:flutter/foundation.dart';
import 'llm_service.dart';
import '../constants/prompts.dart';
import 'model_manager.dart';
import '../utils/chat_history_logger.dart';

class AppState extends ChangeNotifier {
  bool _isModelLoaded = false;
  String _currentMessage = '';
  List<Map<String, String>> _chatHistory = [];
  bool _isProcessing = false;
  final ModelManager _modelManager = ModelManager();

  bool get isModelLoaded => _isModelLoaded;
  String get currentMessage => _currentMessage;
  List<Map<String, String>> get chatHistory => _chatHistory;
  bool get isProcessing => _isProcessing;
  ModelManager get modelManager => _modelManager;

  AppState() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      // Initialize model manager first
      await _modelManager.initialize();

      // Only try to initialize LLM if we have a model
      if (_modelManager.selectedModel != null) {
        await LLMService.initialize();
        setModelLoaded(true);
      } else {
        setModelLoaded(false);
      }
    } catch (e) {
      print('Error initializing model: $e');
      setModelLoaded(false);
    }
  }

  Future<void> reinitializeModel() async {
    // Dispose of current LLM instance so that it can be re-initialized with
    // the newly selected model. Without this, the static LLMService would keep
    // using the previously loaded model.
    LLMService.dispose();

    setModelLoaded(false);
    await _initializeModel();
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

      // Get model info
      final model = _modelManager.selectedModel;
      final modelName = model?.name ?? 'unknown';

      // Generate response using local LLM and measure time
      final stopwatch = Stopwatch()..start();
      // Build recent history excluding the just-added user message to avoid duplication
      List<Map<String, String>> recent = List<Map<String, String>>.from(_chatHistory);
      if (recent.isNotEmpty && recent.last['type'] == 'user') {
        // Exclude the last user entry which is the same as `message`
        recent = recent.sublist(0, recent.length - 1);
      }
      // Keep only the last 2 turns to stay within tiny model context
      final recentHistory = recent.length > 2 ? recent.sublist(recent.length - 2) : recent;
      final response = await LLMService.generateResponse(
        message,
        history: recentHistory,
      );
      stopwatch.stop();
      final responseTimeMs = stopwatch.elapsedMilliseconds;

      // Persist model evaluation info to CSV
      await ChatHistoryLogger.logModelEval(
        modelName: modelName,
        userQuestion: message,
        modelResponse: response,
        responseTimeMs: responseTimeMs,
        promptLabel: kMedicoAIPromptLabel,
      );

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
