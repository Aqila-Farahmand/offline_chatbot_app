package it.aqila.farahmand.medicoai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// MediaPipe Tasks GenAI imports
import android.util.Log
import com.google.mediapipe.tasks.genai.llminference.LlmInference

class MainActivity : FlutterActivity() {
    private val channelName = "mediapipe_llm"
    private var llm: LlmInference? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "modelPath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val options = LlmInference.LlmInferenceOptions.builder()
                            .setModelPath(modelPath)
                            .build()
                        llm = LlmInference.createFromOptions(this, options)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to init LLM", e)
                        result.error("INIT_FAILED", e.message, null)
                    }
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val localLlm = llm
                    if (localLlm == null) {
                        result.error("NOT_INITIALIZED", "LLM not initialized", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val output = localLlm.generateResponse(prompt)
                        result.success(output)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Generation failed", e)
                        result.error("GEN_FAILED", e.message, null)
                    }
                }
                "dispose" -> {
                    try {
                        llm?.close()
                        llm = null
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Dispose failed", e)
                        result.error("DISPOSE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
