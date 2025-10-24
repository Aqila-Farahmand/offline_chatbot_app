// Bridge to MediaPipe Tasks Genai for local inference on web.
import {
  GENAI_BUNDLE_ROOT_PATH,
  GENAI_BUNDLE_LOCAL_ASSET,
  WASM_BASE_PATH,
  MODEL_ASSET_PATH,
} from './config/config.js';  // Update path to match web directory structure

// Expose a plain object on window.MediapipeGenai with async methods init, generate, dispose
window.MediapipeGenai = (function () {
  let llmInference = null;

  async function init(options) {
    const {
      modelAssetPath = MODEL_ASSET_PATH,
      tasksModulePath = GENAI_BUNDLE_LOCAL_ASSET,
      wasmBasePath = WASM_BASE_PATH,
      cpuOnly = false,
      maxTokens = 1280,
    } = options || {};

    console.log('Initializing MediapipeGenai with options:', options);
    window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-start', options } }));

    if (!('WebAssembly' in window)) {
      console.error('WebAssembly not supported in this browser');
      window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-failed', error: 'WebAssembly not supported' } }));
      throw new Error('WebAssembly not supported in this browser');
    }

    let tasks = null;
    // Try local bundle first, then root bundle
    try {
      console.log('Attempting to load tasks module from local assets:', tasksModulePath);
      tasks = await import(tasksModulePath);
      console.log('Successfully loaded tasks module from local assets.');
    } catch (err1) {
      console.warn('Falling back to root assets for tasks module:', err1);
      try {
        console.log('Attempting to load tasks module from root path:', GENAI_BUNDLE_ROOT_PATH);
        tasks = await import(GENAI_BUNDLE_ROOT_PATH);
        console.log('Successfully loaded tasks module from root path.');
      } catch (err2) {
        console.error('Failed to load MediaPipe Tasks Genai module from both local and root paths:', err2);
        throw new Error('Failed to load MediaPipe Tasks Genai module');
      }
    }

    // Resolve WASM base (SIMD detection)
    let resolvedWasmBase = wasmBasePath;
    try {
      console.log('Checking SIMD support for WASM files...');
      await tasks.FilesetResolver.isSimdSupported();
      console.log('SIMD support detected.');
    } catch (err) {
      console.warn('SIMD not supported, falling back to default WASM base path:', err);
      resolvedWasmBase = WASM_BASE_PATH;
    }

    console.log('Resolved WASM base path:', resolvedWasmBase);
    const fileset = await tasks.FilesetResolver.forGenAiTasks(resolvedWasmBase);

    console.log('Creating GenAI task with model asset path:', modelAssetPath);

    // Build base create options
    const baseCreateOptions = {
      baseOptions: {
        modelAssetPath,
      },
      decodingConfig: {
        max_num_tokens: maxTokens,
        max_seq_length: maxTokens,
        maxTopK: 5,
        numOutputCandidates: 1,
        temperature: 0.1,
        stopTokens: ["<eos>", "<end_of_turn>", "User:", "\nUser:"],
      },
      forceF32: true,
    };

    // If cpuOnly requested, force CPU backend immediately
    if (cpuOnly) {
      baseCreateOptions.executorBackend = 'CPU';
      baseCreateOptions.useCpu = true;
      window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-info', info: 'Forcing CPU backend as requested' } }));
    }

    // Attempt to create task; if GPU delegate fails, optionally retry forcing CPU backend
    try {
      llmInference = await tasks.LlmInference.createFromOptions(fileset, baseCreateOptions);
    } catch (errCreate) {
      console.error('Initial createFromOptions failed:', errCreate);
      // If cpuOnly was already requested and we failed, surface failure
      if (cpuOnly) {
        window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-failed', error: String(errCreate) } }));
        throw errCreate;
      }

      // Retry with CPU override
      console.warn('Retrying createFromOptions forcing CPU backend...');
      window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-retry-cpu' } }));
      try {
        const cpuOptions = { ...baseCreateOptions, executorBackend: 'CPU', useCpu: true };
        llmInference = await tasks.LlmInference.createFromOptions(fileset, cpuOptions);
      } catch (errCreate2) {
        console.error('Retry with CPU failed:', errCreate2);
        window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-failed', error: String(errCreate2) } }));
        throw errCreate2;
      }
    }

    console.log('GenAI task successfully created.');
    window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-success' } }));
    return true;
  }

  async function generate(prompt) {
    if (!llmInference) {
      throw new Error('MediapipeGenai not initialized');
    }

    window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'generate-start' } }));

    // Delegate to the underlying LLM inference API
    // The MediaPipe API exposes generateResponse on the LlmInference instance
    try {
      const result = await llmInference.generateResponse(prompt);
      window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'generate-success', result } }));
      // result may be an object or string depending on the API; normalize to string
      if (typeof result === 'string') return result;
      if (result && typeof result.text === 'string') return result.text;
      // Fallback: stringify
      return JSON.stringify(result);
    } catch (err) {
      console.error('Error generating response from LLM:', err);
      window.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'generate-failed', error: String(err) } }));
      throw err;
    }
  }

  function dispose() {
    if (llmInference && typeof llmInference.close === 'function') {
      try {
        llmInference.close();
      } catch (err) {
        console.warn('MediapipeGenai.dispose: failed to close task', err);
      }
    }
    llmInference = null;
  }

  return { init, generate, dispose };
})();
