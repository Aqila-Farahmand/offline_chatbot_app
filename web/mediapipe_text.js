// Minimal bridge to MediaPipe Tasks Text for offline local inference on web.
// Expects the following files to be present and served locally:
// - assets/mediapipe/text_bundle.mjs (ESM entry)
// - assets/mediapipe/wasm/ (the required .wasm and support files)
// - A .task model under assets/models/<name>.task

window.MediapipeText = (function () {
  let textTask = null;

  async function init(options) {
    const {
      modelAssetPath = './assets/models/',
      tasksModulePath = './assets/mediapipe/text_bundle.mjs',
      wasmBasePath = './assets/mediapipe/wasm',
    } = options || {};

    if (!('WebAssembly' in window)) {
      throw new Error('WebAssembly not supported in this browser');
    }

    // Dynamically import the MediaPipe Tasks Text ESM from local assets
    const tasks = await import(tasksModulePath);

    // Build the base options for WASM files location
    const fileset = await tasks.FilesetResolver.forTextTasks(wasmBasePath);

    // Create the text generation task with local model asset
    textTask = await tasks.TextEmbedder.createFromOptions(fileset, {
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
    if (!textTask) {
      throw new Error('MediapipeText not initialized');
    }
    // Placeholder: MediaPipe currently exposes TextEmbedder / NLClassifier widely.
    // If TextGenerator API is available, replace this with generation call.
    // For now, just echo to demonstrate plumbing; real generation requires
    // TextGenerator support in the bundled text_bundle.mjs.
    return `Local (web) generation is configured, but the TextGenerator API is not available in this build. Prompt: ${prompt}`;
  }

  function dispose() {
    if (textTask && typeof textTask.close === 'function') {
      try {
        textTask.close();
      } catch (err) {
        console.warn('MediapipeText.dispose: failed to close task', err);
      }
    }
    textTask = null;
  }

  return { init, generate, dispose };
})();


