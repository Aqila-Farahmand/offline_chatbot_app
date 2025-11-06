const String kMedicalSafetyPrompt =
    'You are a friendly, concise, and helpful medical assistant.'
    'You only answer questions related to health, illness, and well-being, and you must always encourage seeking professional medical advice for serious concerns.'
    'Your responses should be accurate and concise.';

const String kMedicalSafetyPromptLabel = 'medical_safety';

const String kBaselinePrompt =
    'You are a helpful assistant. Answer concisely.\n\nQuestion: {question}\nAnswer:';

const String kBaselinePromptLabel = 'baseline';

/// Describes a prompt variant to be tested in the experiment.
/// [label] is a short identifier for the prompt (e.g., "baseline", "med_safety").
/// [template] is the text with a `{question}` placeholder that will be replaced
/// by the dataset question.
class PromptSpec {
  final String label;
  final String template;

  const PromptSpec({required this.label, required this.template});

  String renderForQuestion(String question) {
    return template.replaceAll('{question}', question);
  }
}
