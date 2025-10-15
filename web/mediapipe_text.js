// Minimal bridge to MediaPipe Tasks Genai for offline local inference on web.
// Expects the following files to be present and served locally:
// - assets/mediapipe/genai_bundle.mjs (ESM entry)
// - assets/mediapipe/wasm/ (the required .wasm and support files)
// - A .task model under assets/models/<name>.task

window.MediapipeGenai = (function () {
  let genaiTask = null;

  async function init(options) {
    const {
      modelAssetPath = '/assets/models/gemma3-1b-it-int8-web.task',
      tasksModulePath = '/assets/mediapipe/genai_bundle.mjs',
      wasmBasePath = '/assets/mediapipe/wasm',
    } = options || {};

    if (!('WebAssembly' in window)) {
      throw new Error('WebAssembly not supported in this browser');
    }

    // Dynamically import the MediaPipe Tasks Genai from local assets, fallback to web/ if needed
    let tasks;
    try {
      tasks = await import(tasksModulePath);
    } catch (err1) {
      console.warn('Falling back to ./assets for tasks module:', err1);
      try {
        tasks = await import('./assets/mediapipe/genai_bundle.mjs');
      } catch (err2) {
        console.warn('Falling back to web/assets for tasks module:', err2);
        tasks = await import('web/assets/mediapipe/genai_bundle.mjs');
      }
    }

    // Build the base options for WASM files location (note the casing: GenAi)
    let resolvedWasmBase = wasmBasePath;
    try {
      // Probe by attempting to resolve fileset; if it throws, fall back
      await tasks.FilesetResolver.isSimdSupported();
    } catch (err) {
      console.warn('Falling back to ./assets for WASM base path:', err);
      resolvedWasmBase = './assets/mediapipe/wasm';
    }
    const fileset = await tasks.FilesetResolver.forGenAiTasks(resolvedWasmBase);

    // Create the LLM inference task with local model asset
    genaiTask = await tasks.LlmInference.createFromOptions(fileset, {
      baseOptions: {
        modelAssetPath,
      },
      // Align precision and cache sizing with the model to avoid WebGPU delegate errors
      maxTokens: 1280,
      forceF32: true,
    });

    // Note: If using TextGenerator when available:
    // textTask = await tasks.TextGenerator.createFromOptions(fileset, {
    //   baseOptions: { modelAssetPath },
    // });

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


