#include <cstring>
#include <string>
#include <vector>
#include <iostream>
#include <android/log.h>
#include "llama.h"

#define LOG_TAG "LlamaBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global state (for demo; production code should avoid globals)
llama_model *g_model = nullptr;
llama_context *g_ctx = nullptr;
llama_sampler *g_sampler = nullptr;

extern "C" {

// Initialize the llama model and context
bool initLlama(const char *model_path_c_str) {
    LOGI("initLlama: Starting initialization with model: %s", model_path_c_str);
    
    // Free previous state if any
    if (g_sampler) {
        LOGI("initLlama: Freeing previous sampler");
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    if (g_ctx) {
        LOGI("initLlama: Freeing previous context");
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model) {
        LOGI("initLlama: Freeing previous model");
        llama_model_free(g_model);
        g_model = nullptr;
    }

    // Load dynamic backends
    LOGI("initLlama: Loading dynamic backends");
    ggml_backend_load_all();

    // Initialize the model
    LOGI("initLlama: Loading model from file");
    llama_model_params model_params = llama_model_default_params();
    g_model = llama_model_load_from_file(model_path_c_str, model_params);
    if (!g_model) {
        LOGE("initLlama: Failed to load model from %s", model_path_c_str);
        return false;
    }
    LOGI("initLlama: Model loaded successfully");

    // Initialize the context
    LOGI("initLlama: Creating context");
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 128; // Drastically reduced from 512 to 128
    ctx_params.n_batch = 32; // Drastically reduced from 256 to 32
    ctx_params.no_perf = false;

    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("initLlama: Failed to create llama context");
        llama_model_free(g_model);
        g_model = nullptr;
        return false;
    }
    LOGI("initLlama: Context created successfully");

    // Initialize the sampler
    LOGI("initLlama: Creating sampler");
    auto sparams = llama_sampler_chain_default_params();
    sparams.no_perf = false;
    g_sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(g_sampler, llama_sampler_init_greedy());
    LOGI("initLlama: Sampler created successfully");

    LOGI("initLlama: Initialization completed successfully");
    return true;
}

// Generate text for a prompt (returns a malloc'd C string, caller must free)
const char *generateText(const char *prompt_c_str) {
    if (!g_ctx || !g_model || !g_sampler) {
        LOGE("Llama context not initialized!");
        return strdup("Llama context not initialized!");
    }

    try {
        LOGI("generateText: Starting with prompt: %s", prompt_c_str);
        
        const llama_vocab *vocab = llama_model_get_vocab(g_model);
        if (!vocab) {
            LOGE("generateText: Failed to get vocabulary");
            return strdup("Failed to get vocabulary from model");
        }

        LOGI("generateText: Got vocabulary successfully");

        // Tokenize the prompt
        const int n_prompt = -llama_tokenize(vocab, prompt_c_str, strlen(prompt_c_str), NULL, 0, true, true);
        if (n_prompt < 0) {
            LOGE("generateText: Failed to get prompt token count");
            return strdup("Failed to get prompt token count.");
        }

        if (n_prompt == 0) {
            LOGE("generateText: Empty prompt after tokenization");
            return strdup("Empty prompt after tokenization.");
        }

        LOGI("generateText: Token count: %d", n_prompt);

        std::vector<llama_token> prompt_tokens(n_prompt);
        if (llama_tokenize(vocab, prompt_c_str, strlen(prompt_c_str), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
            LOGE("generateText: Failed to tokenize prompt");
            return strdup("Failed to tokenize prompt.");
        }

        LOGI("generateText: Tokenization successful");

        // Check if context and model are valid
        if (!g_ctx) {
            LOGE("generateText: Context is null");
            return strdup("Context is null");
        }
        
        if (!g_model) {
            LOGE("generateText: Model is null");
            return strdup("Model is null");
        }

        LOGI("generateText: Context and model are valid");

        // Prepare a batch for the prompt
        llama_batch batch = llama_batch_get_one(prompt_tokens.data(), prompt_tokens.size());
        LOGI("generateText: Created batch with %zu tokens", prompt_tokens.size());

        // Evaluate the prompt
        LOGI("generateText: Evaluating prompt tokens...");
        LOGI("generateText: About to call llama_decode...");
        int decode_result = llama_decode(g_ctx, batch);
        LOGI("generateText: llama_decode returned: %d", decode_result);
        
        if (decode_result != 0) {
            LOGE("generateText: Failed to evaluate prompt, error code: %d", decode_result);
            return strdup("Failed to evaluate prompt tokens.");
        }
        LOGI("generateText: Prompt evaluation successful");

        // Generate text tokens
        std::vector<llama_token> output_tokens;
        const int max_tokens = 50; // Increased from 5 to 50 for better responses
        
        LOGI("generateText: Starting text generation loop");
        
        for (int i = 0; i < max_tokens; ++i) {
            // Sample next token
            llama_token next_token = llama_sampler_sample(g_sampler, g_ctx, -1);
            
            LOGI("generateText: Generated token %d: %d", i, next_token);
            
            // Check for end of generation
            if (next_token == llama_vocab_eos(vocab)) {
                LOGI("generateText: Reached EOS token");
                break;
            }
            
            output_tokens.push_back(next_token);
            
            // Evaluate the next token
            llama_batch next_batch = llama_batch_get_one(&next_token, 1);
            int decode_result = llama_decode(g_ctx, next_batch);
            LOGI("generateText: Next token decode result: %d", decode_result);
            
            if (decode_result != 0) {
                LOGE("generateText: Failed to decode next token");
                break;
            }
            
            // Stop at natural sentence endings
            if (i >= 10) {
                if (next_token == 236787 || next_token == 236888 || next_token == 236761) { // : ! .
                    LOGI("generateText: Stopping at sentence end");
                    break;
                }
            }
        }

        LOGI("generateText: Generated %zu output tokens", output_tokens.size());

        // Convert output_tokens to string
        std::string result_text;
        for (size_t i = 0; i < output_tokens.size(); i++) {
            auto t = output_tokens[i];
            char buf[128];
            int n = llama_token_to_piece(vocab, t, buf, sizeof(buf), 0, true);
            LOGI("generateText: Converting token %zu (%d) to piece, result: %d", i, t, n);
            if (n > 0) {
                std::string piece(buf, n);
                result_text += piece;
                LOGI("generateText: Added piece: '%s'", piece.c_str());
            } else {
                LOGI("generateText: Token %zu (%d) produced no piece", i, t);
            }
        }

        LOGI("generateText: Final result text: '%s'", result_text.c_str());
        return strdup(result_text.c_str());
        
    } catch (const std::exception& e) {
        LOGE("Exception in generateText: %s", e.what());
        return strdup("Exception occurred during text generation.");
    } catch (...) {
        LOGE("Unknown exception in generateText");
        return strdup("Unknown error occurred during text generation.");
    }
}

// Free the llama context and model
void freeLlama() {
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    if (g_ctx) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
}

} // extern "C"
