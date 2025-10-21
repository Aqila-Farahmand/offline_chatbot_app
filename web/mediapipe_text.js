// Bridge to MediaPipe Tasks Genai for local inference on web.
import {
  GENAI_BUNDLE_ROOT_PATH,
  GENAI_BUNDLE_LOCAL_ASSET,
    WASM_BASE_PATH,
    MODEL_ASSET_PATH,
} from '../config/config.js';

window.MediapipeGenai = (function () {
  let genaiTask = null;

  async function init(options) {
    const {
      modelAssetPath = MODEL_ASSET_PATH,
      tasksModulePath = GENAI_BUNDLE_LOCAL_ASSET,
      wasmBasePath = WASM_BASE_PATH,
    } = options || {};

    if (!('WebAssembly' in window)) {
      throw new Error('WebAssembly not supported in this browser');
    }

    let tasks;

    // Attempt to dynamically import the MediaPipe Tasks Genai from local assets, fallback to root path if needed.
    try {
      tasks = await import(tasksModulePath);
    } catch (err1) {
      console.warn('Falling back to root assets for tasks module:', err1);
      try {
        tasks = await import(GENAI_BUNDLE_ROOT_PATH);
      } catch (err2) {
        throw new Error('Failed to load MediaPipe Tasks Genai module from both local and root paths');
      }
    }

    // Build the base options for WASM files location
    let resolvedWasmBase = wasmBasePath;
    try {
      // Probe by attempting to resolve fileset; if it throws, fall back
      await tasks.FilesetResolver.isSimdSupported();
    } catch (err) {
      console.warn('Falling back to default WASM base path:', err);
      resolvedWasmBase = WASM_BASE_PATH;
    }
    const fileset = await tasks.FilesetResolver.forGenAiTasks(resolvedWasmBase);

    genaiTask = await tasks.LlmInference.createFromOptions(fileset, {
        baseOptions: {
            modelAssetPath,
        },
        decodingConfig: {
            maxNumTokens: 80, // Adjusted for shorter, more deterministic output
            maxSeqLength: 1280, // Ensure sufficient context length
            maxTopK: 5, // Adjusted for deterministic output
            numOutputCandidates: 1, // Single output for chatbot
            temperature: 0.1, // Set low for predictable output
            stopTokens: [
                "<eos>",
                "<end_of_turn>",
                "User:", // The literal string the model generates next
                "\nUser:", // A common variation
            ],
        },
        forceF32: true, // This is a top-level option
    });
    return true;
  }

  async function generate(prompt) {
    if (!genaiTask) {
      throw new Error('MediapipeGenai not initialized');
    }
    // Generate a response using the MediaPipe LLM inference API
    return await genaiTask.generateResponse(prompt);
  }

  function dispose() {
    if (genaiTask && typeof genaiTask.close === 'function') {
      try {
        genaiTask.close();
      } catch (err) {
        console.warn('MediapipeGenai.dispose: failed to close task', err);
      }
    }
    genaiTask = null;
  }

  return { init, generate, dispose };
})();
