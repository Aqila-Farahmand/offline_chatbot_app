package it.aqila.farahmand.medicoai

class LlamaBridge {
    companion object {
        init {
            // Load the native library when this class is loaded
            // The name must match the name given in add_library in CMakeLists.txt (without lib prefix or .so suffix)
            System.loadLibrary("llama_native")
        }
    }

    // Native method declarations (matching the JNIEXPORT functions in llama_bridge.cpp)
    external fun initLlama(modelPath: String): Boolean
    external fun generateText(prompt: String): String
    external fun freeLlama()
}
