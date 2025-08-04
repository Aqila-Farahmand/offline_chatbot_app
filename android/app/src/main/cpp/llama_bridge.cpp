#include <cstring>
#include <string>
#include <vector>
#include <iostream>
#include "llama.h"

// Global state (for demo; production code should avoid globals)
llama_model *g_model = nullptr;
llama_context *g_ctx = nullptr;
llama_sampler *g_sampler = nullptr;

extern "C" {

// Initialize the llama model and context
bool initLlama(const char *model_path_c_str) {
    // Free previous state if any
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

    // Load dynamic backends
    ggml_backend_load_all();

    // Initialize the model
    llama_model_params model_params = llama_model_default_params();
    g_model = llama_model_load_from_file(model_path_c_str, model_params);
    if (!g_model) {
        std::cerr << "Failed to load model from " << model_path_c_str << std::endl;
        return false;
    }

    // Initialize the context
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048; // context window
    ctx_params.n_batch = 512; // batch size
    ctx_params.no_perf = false;

    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (!g_ctx) {
        std::cerr << "Failed to create llama context" << std::endl;
        llama_model_free(g_model);
        g_model = nullptr;
        return false;
    }

    // Initialize the sampler
    auto sparams = llama_sampler_chain_default_params();
    sparams.no_perf = false;
    g_sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(g_sampler, llama_sampler_init_greedy());

    return true;
}

// Generate text for a prompt (returns a malloc'd C string, caller must free)
const char *generateText(const char *prompt_c_str) {
    if (!g_ctx || !g_model || !g_sampler) {
        return strdup("Llama context not initialized!");
    }

    const llama_vocab *vocab = llama_model_get_vocab(g_model);

    // Tokenize the prompt
    const int n_prompt = -llama_tokenize(vocab, prompt_c_str, strlen(prompt_c_str), NULL, 0, true, true);
    if (n_prompt < 0) {
        return strdup("Failed to get prompt token count.");
    }

    std::vector<llama_token> prompt_tokens(n_prompt);
    if (llama_tokenize(vocab, prompt_c_str, strlen(prompt_c_str), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        return strdup("Failed to tokenize prompt.");
    }

    // Print the prompt token-by-token
    std::string result_text;
    for (auto id : prompt_tokens) {
        char buf[128];
        int n = llama_token_to_piece(vocab, id, buf, sizeof(buf), 0, true);
        if (n > 0) {
            result_text += std::string(buf, n);
        }
    }

    // Prepare a batch for the prompt
    llama_batch batch = llama_batch_get_one(prompt_tokens.data(), prompt_tokens.size());

    // Main generation loop
    int n_predict = 100; // number of tokens to generate
    llama_token new_token_id;

    for (int n_pos = 0; n_pos + batch.n_tokens < prompt_tokens.size() + n_predict; ) {
        // Evaluate the current batch with the transformer model
        if (llama_decode(g_ctx, batch)) {
            llama_batch_free(batch);
            return strdup("Failed to decode.");
        }

        n_pos += batch.n_tokens;

        // Sample the next token
        new_token_id = llama_sampler_sample(g_sampler, g_ctx, -1);

        // Check if it's an end of generation
        if (llama_vocab_is_eog(vocab, new_token_id)) {
            break;
        }

        // Convert token to string and add to result
        char buf[128];
        int n = llama_token_to_piece(vocab, new_token_id, buf, sizeof(buf), 0, true);
        if (n > 0) {
            result_text += std::string(buf, n);
        }

        // Prepare the next batch with the sampled token
        llama_batch_free(batch);
        batch = llama_batch_get_one(&new_token_id, 1);
    }

    llama_batch_free(batch);
    return strdup(result_text.c_str());
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
