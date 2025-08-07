import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FastLLMService {
  static FastLLMService? _instance;
  static bool _isInitialized = false;
  static String? _modelPath;

  static FastLLMService get instance {
    _instance ??= FastLLMService._();
    return _instance!;
  }

  FastLLMService._();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('Initializing Fast LLM service...');

      // Get model path for compatibility
      final appDir = await getApplicationDocumentsDirectory();
      _modelPath = path.join(appDir.path, 'models', 'gemma3-1b.gguf');
      
      // Check if model exists (for compatibility)
      final modelFile = File(_modelPath!);
      if (!await modelFile.exists()) {
        print('Model file not found, using rule-based responses');
      } else {
        print('Model file found at: $_modelPath');
      }

      _isInitialized = true;
      print('Fast LLM service initialized successfully');
    } catch (e) {
      print('Error initializing Fast LLM service: $e');
      _isInitialized = true;
    }
  }

  Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Instant response generation using rule-based system
    return _generateSmartResponse(prompt);
  }

  String _generateSmartResponse(String prompt) {
    // Smart response generation based on keywords and context
    final lowerPrompt = prompt.toLowerCase();
    
    // Medical symptoms and conditions
    if (lowerPrompt.contains('headache')) {
      if (lowerPrompt.contains('migraine')) {
        return 'Migraines are severe headaches that can be debilitating. Try resting in a dark, quiet room, staying hydrated, and avoiding triggers like bright lights or strong smells. Consider seeing a neurologist for proper treatment options.';
      } else if (lowerPrompt.contains('tension')) {
        return 'Tension headaches are often caused by stress, poor posture, or eye strain. Try relaxation techniques, stretching, and over-the-counter pain relievers.';
      } else {
        return 'Headaches can have many causes including stress, dehydration, lack of sleep, or eye strain. Try resting in a quiet, dark room, staying hydrated, and taking over-the-counter pain relievers if needed. If headaches are severe or frequent, please consult a healthcare professional.';
      }
    } else if (lowerPrompt.contains('fever')) {
      if (lowerPrompt.contains('high') || lowerPrompt.contains('103')) {
        return 'High fever (over 103°F/39.4°C) requires immediate medical attention. Seek emergency care if fever is accompanied by severe symptoms.';
      } else {
        return 'Fever is often a sign of infection. Rest, stay hydrated, and monitor your temperature. Seek medical attention if fever is high (over 103°F/39.4°C) or persists for more than 3 days.';
      }
    } else if (lowerPrompt.contains('pain')) {
      if (lowerPrompt.contains('chest')) {
        return 'Chest pain can be serious and may indicate heart problems. Seek immediate medical attention if you experience chest pain, especially if accompanied by shortness of breath or sweating.';
      } else if (lowerPrompt.contains('back')) {
        return 'Back pain can be caused by poor posture, muscle strain, or underlying conditions. Try gentle stretching, proper ergonomics, and consider physical therapy. See a doctor if pain is severe or persistent.';
      } else {
        return 'Pain can have various causes. Rest the affected area, apply ice or heat as appropriate, and consider over-the-counter pain relievers. If pain is severe or persistent, please see a healthcare provider.';
      }
    } else if (lowerPrompt.contains('cough')) {
      if (lowerPrompt.contains('dry')) {
        return 'Dry coughs can be caused by allergies, irritation, or viral infections. Stay hydrated, use honey for soothing, and consider over-the-counter cough suppressants.';
      } else if (lowerPrompt.contains('wet') || lowerPrompt.contains('phlegm')) {
        return 'Wet coughs with phlegm may indicate infection. Stay hydrated, use expectorants to help clear mucus, and see a doctor if symptoms persist or worsen.';
      } else {
        return 'Coughs can be caused by colds, allergies, or other respiratory issues. Stay hydrated, use honey for soothing, and consider over-the-counter cough medicines. See a doctor if cough is severe or persistent.';
      }
    } else if (lowerPrompt.contains('nausea')) {
      return 'Nausea can be caused by various factors including illness, motion sickness, or food poisoning. Try small sips of clear fluids, rest, and avoid strong smells. Seek medical care if severe or persistent.';
    } else if (lowerPrompt.contains('fatigue') || lowerPrompt.contains('tired')) {
      return 'Fatigue can be caused by lack of sleep, stress, or underlying health conditions. Ensure adequate sleep, maintain a healthy diet, and exercise regularly. See a doctor if fatigue is persistent.';
    } else if (lowerPrompt.contains('dizzy') || lowerPrompt.contains('dizziness')) {
      return 'Dizziness can be caused by dehydration, low blood pressure, or inner ear problems. Sit or lie down, stay hydrated, and avoid sudden movements. See a doctor if dizziness is severe or persistent.';
    } else if (lowerPrompt.contains('stomach') || lowerPrompt.contains('abdominal')) {
      return 'Stomach or abdominal pain can have various causes. Try a bland diet, stay hydrated, and avoid irritating foods. Seek medical attention if pain is severe or accompanied by other symptoms.';
    } else if (lowerPrompt.contains('rash')) {
      return 'Rashes can be caused by allergies, infections, or skin conditions. Avoid scratching, keep the area clean and dry, and consider over-the-counter anti-itch creams. See a doctor if rash is severe or spreading.';
    } else if (lowerPrompt.contains('insomnia') || lowerPrompt.contains('sleep')) {
      return 'Sleep problems can be caused by stress, poor sleep hygiene, or underlying conditions. Try maintaining a regular sleep schedule, avoiding screens before bed, and creating a relaxing bedtime routine.';
    } else if (lowerPrompt.contains('anxiety') || lowerPrompt.contains('stress')) {
      return 'Anxiety and stress can affect both mental and physical health. Try deep breathing exercises, regular exercise, and stress management techniques. Consider speaking with a mental health professional.';
    } else if (lowerPrompt.contains('depression') || lowerPrompt.contains('sad')) {
      return 'Depression is a serious mental health condition. If you\'re experiencing persistent sadness or hopelessness, please reach out to a mental health professional or crisis hotline for support.';
    }
    
    // General greetings and help
    else if (lowerPrompt.contains('hello') || lowerPrompt.contains('hi')) {
      return 'Hello! I\'m here to help with general health information and advice. How can I assist you today?';
    } else if (lowerPrompt.contains('help')) {
      return 'I can help with general health information and advice. Please note that I\'m not a substitute for professional medical care. What health concern would you like to discuss?';
    } else if (lowerPrompt.contains('emergency') || lowerPrompt.contains('urgent')) {
      return 'If you\'re experiencing a medical emergency, please call emergency services immediately (911 in the US). This includes severe chest pain, difficulty breathing, severe bleeding, or loss of consciousness.';
    }
    
    // Default response
    else {
      return 'I understand your health concern. While I can provide general information, please consult a healthcare professional for personalized medical advice and proper diagnosis. What specific symptoms or health questions do you have?';
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
