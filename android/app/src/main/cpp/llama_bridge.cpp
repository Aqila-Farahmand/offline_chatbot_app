#include <jni.h> // If you plan to use JNI directly (less common with Flutter FFI)
#include <string>
#include <vector>
#include <iostream>

// Include necessary llama.cpp headers
#include "../../../../../llama.cpp/llama.h" // Adjust path based on your setup

// Declare a global context for llama.cpp (simplify for example)
llama_context * g_ctx = nullptr;
llama_model * g_model = nullptr;

extern "C" { // Expose C functions for Dart FFI

// Initialize the llama model and context
// model_path_c_str: path to the GGUF model file on the device
JNIEXPORT jboolean JNICALL
Java_com_example_myllama_app_LlamaBridge_initLlama(JNIEnv* env, jobject /* this */, jstring model_path_jstring) {
    if (g_ctx != nullptr) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model != nullptr) {
        llama_free_model(g_model);
        g_model = nullptr;
    }

    const char* model_path_c_str = env->GetStringUTFChars(model_path_jstring, 0);

    llama_backend_init(true); // Initialize llama.cpp backend

    llama_model_params model_params = llama_model_default_params();
    g_model = llama_load_model_from_file(model_path_c_str, model_params);

    if (g_model == nullptr) {
        std::cerr << "Failed to load model from " << model_path_c_str << std::endl;
        env->ReleaseStringUTFChars(model_path_jstring, model_path_c_str);
        return JNI_FALSE;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.seed = 1234;
    ctx_params.n_ctx = 2048; // Context size
    ctx_params.n_gpu_layers = 0; // Set to > 0 to offload layers to GPU if supported (e.g., Metal on iOS, or OpenCL/Vulkan backend if built with it)

    g_ctx = llama_new_context_with_model(g_model, ctx_params);

    if (g_ctx == nullptr) {
        std::cerr << "Failed to create llama context" << std::endl;
        llama_free_model(g_model);
        g_model = nullptr;
        env->ReleaseStringUTFChars(model_path_jstring, model_path_c_str);
        return JNI_FALSE;
    }

    env->ReleaseStringUTFChars(model_path_jstring, model_path_c_str);
    return JNI_TRUE;
}

// Generate text (simplified for example)
JNIEXPORT jstring JNICALL
Java_com_example_myllama_app_LlamaBridge_generateText(JNIEnv* env, jobject /* this */, jstring prompt_jstring) {
    if (g_ctx == nullptr) {
        return env->NewStringUTF("Llama context not initialized!");
    }

    const char* prompt_c_str = env->GetStringUTFChars(prompt_jstring, 0);
    std::string result_text = "";

    // Tokenize the prompt
    std::vector<llama_token> tokens;
    tokens.resize(llama_get_model_n_ctx(g_model)); // Allocate enough space

    int n_tokens = llama_tokenize(g_model, prompt_c_str, strlen(prompt_c_str), tokens.data(), tokens.size(), true, false);
    tokens.resize(n_tokens);

    if (n_tokens < 0) {
        env->ReleaseStringUTFChars(prompt_jstring, prompt_c_str);
        return env->NewStringUTF("Failed to tokenize prompt.");
    }

    // Evaluate the prompt
    if (llama_decode(g_ctx, llama_batch_get_one(tokens.data(), tokens.size(), 0, 0)) != 0) {
        env->ReleaseStringUTFChars(prompt_jstring, prompt_c_str);
        return env->NewStringUTF("Failed to decode prompt.");
    }

    // Generate tokens
    for (int i = 0; i < 100; ++i) { // Generate up to 100 new tokens
        llama_token new_token_id = llama_sample_token(g_ctx, llama_sampling_context_from_sample_for_context(g_ctx), llama_token_data_array{llama_get_logits(g_ctx), llama_n_vocab(g_model), false});

        if (new_token_id == llama_token_eos(g_model)) {
            break;
        }

        result_text += llama_token_to_piece(g_ctx, new_token_id).c_str();

        // Append new token to the batch
        llama_batch batch = llama_batch_init(1, 0, 1);
        llama_batch_add(batch, new_token_id, llama_get_kv_cache_token_count(g_ctx), {0}, false);

        if (llama_decode(g_ctx, batch) != 0) {
            result_text += "Failed to decode new token.";
            break;
        }
    }

    env->ReleaseStringUTFChars(prompt_jstring, prompt_c_str);
    return env->NewStringUTF(result_text.c_str());
}


// Free the llama context and model
JNIEXPORT void JNICALL
Java_com_example_myllama_app_LlamaBridge_freeLlama(JNIEnv* env, jobject /* this */) {
if (g_ctx != nullptr) {
llama_free(g_ctx);
g_ctx = nullptr;
}
if (g_model != nullptr) {
llama_free_model(g_model);
g_model = nullptr;
}
llama_backend_free();
}

} // extern "C"
