import 'package:flutter/foundation.dart';
import 'llm_service.dart';
import 'model_manager.dart';
import '../utils/chat_history_logger.dart';
import '../utils/chat_history_remote_logger.dart';

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

      // Initialize LLM on all platforms if a model exists
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
      final response = await LLMService.generateResponse(message);
      stopwatch.stop();
      final responseTimeMs = stopwatch.elapsedMilliseconds;

      // Add bot response to chat first (don't wait for logging)
      addMessageToHistory(response, false);

      // Persist model evaluation info to CSV (local) and Firestore (remote)
      // These are fire-and-forget operations that won't block the UI
      ChatHistoryLogger.logModelEval(
        modelName: modelName,
        userQuestion: message,
        modelResponse: response,
        promptLabel: LLMService.currentPromptLabel,
        responseTimeMs: responseTimeMs,
      ).catchError((e) => print('Local logging error: $e'));

      ChatHistoryRemoteLogger.logModelEvalRemote(
        modelName: modelName,
        userQuestion: message,
        modelResponse: response,
        promptLabel: LLMService.currentPromptLabel,
        responseTimeMs: responseTimeMs,
      ).catchError((e) => print('Remote logging error: $e'));
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
