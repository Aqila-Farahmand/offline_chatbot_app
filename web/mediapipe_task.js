// Minimal bridge to MediaPipe Tasks Genai for offline local inference on web.
// Expects the following files to be present and served locally:
// - assets/mediapipe/genai_bundle.mjs (ESM entry)
// - assets/mediapipe/wasm/ (the required .wasm and support files)
// - A .task model under assets/models/<name>.task

window.MediapipeGenai = (function () {
  let genaiTask = any;

  async function init(options) {
    const {
      modelAssetPath = './assets/models/gemma3-1b-it-int8-web.task',
      tasksModulePath = './assets/mediapipe/genai_bundle.mjs',
      wasmBasePath = './assets/mediapipe/wasm',
    } = options || {};

    if (!('WebAssembly' in window)) {
      throw new Error('WebAssembly not supported in this browser');
    }

    // Dynamically import the MediaPipe Tasks Genai from local assets
    const tasks = await import(tasksModulePath);

    // Build the base options for WASM files location
    const fileset = await tasks.FilesetResolver.forGenaiTasks(wasmBasePath);

    // Create the text generation task with local model asset
    genaiTask = await tasks.Genai.createFromOptions(fileset, {
      baseOptions: {
        modelAssetPath,
      },
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
    // Placeholder: MediaPipe currently exposes TextEmbedder / NLClassifier widely.
    // If TextGenerator API is available, replace this with generation call.
    // For now, just echo to demonstrate plumbing; real generation requires
    // TextGenerator support in the bundled genai_bundle.mjs.
    return `Local (web) generation is configured, but the TextGenerator API is not available in this build. Prompt: ${prompt}`;
  }

  function dispose() {
    if (textTask && typeof textTask.close === 'function') {
      try {
        textTask.close();
      } catch (err) {
        console.warn('MediapipeGenai.dispose: failed to close task', err);
      }
    }
    genaiTask = null;
  }

  return { init, generate, dispose };
})();


