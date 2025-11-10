// Bridge to MediaPipe Tasks Genai for local inference on web.
import {
  GENAI_BUNDLE_ROOT_PATH,
  GENAI_BUNDLE_LOCAL_ASSET,
  WASM_BASE_PATH,
  MODEL_ASSET_PATH,
} from './config/config.js';

// Expose a plain object on a globalThis.MediapipeGenai with async methods init, generate, dispose
globalThis.MediapipeGenai = (function () {
  let llmInference = null;

  // Helper function to resolve URL considering base href
  function resolveModuleUrl(path) {
    // If it's already a full URL, return it
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    // Get base href from document
    const baseElement = document.querySelector('base');
    const baseHref = baseElement?.getAttribute('href') || '/';
    
    // If path starts with '/', it's absolute from origin
    if (path.startsWith('/')) {
      return new URL(path, globalThis.location.origin).href;
    }
    
    // Relative path - resolve against base href
    const baseUrl = new URL(baseHref, globalThis.location.href);
    return new URL(path, baseUrl).href;
  }

  // Load the MediaPipe Tasks GenAI module
  async function loadTasksModule(tasksModulePath) {
    // Use config paths only - no hardcoded paths
    const pathsToTry = [
      tasksModulePath, // From options
      GENAI_BUNDLE_ROOT_PATH, // From config
      GENAI_BUNDLE_LOCAL_ASSET, // From config
    ];
    
    let lastError = null;
    let lastErrorDetails = null;
    
    for (const path of pathsToTry) {
      try {
        const moduleUrl = resolveModuleUrl(path);
        console.log('Attempting to load tasks module from:', path, '-> resolved to:', moduleUrl);
        
        try {
          const response = await fetch(moduleUrl, { method: 'HEAD' });
          if (!response.ok) {
            console.warn(`File not accessible at ${moduleUrl}: ${response.status} ${response.statusText}`);
            lastError = new Error(`HTTP ${response.status}: ${response.statusText}`);
            lastErrorDetails = { path, moduleUrl, status: response.status, statusText: response.statusText };
            continue;
          }
        } catch (error_) {
          console.warn(`Failed to verify file accessibility at ${moduleUrl}:`, error_);
        }
        
        const tasks = await import(moduleUrl);
        console.log('Successfully loaded tasks module from:', path);
        return tasks;
      } catch (err) {
        console.warn(`Failed to load from ${path}:`, err);
        lastError = err;
        lastErrorDetails = { path, error: err.message || String(err), stack: err.stack };
      }
    }
    
    const errorMsg = `Failed to load MediaPipe Tasks Genai module from all attempted paths. Last error: ${lastError?.message || lastError}`;
    console.error(errorMsg, lastError);
    console.error('Attempted paths:', pathsToTry);
    console.error('Last error details:', lastErrorDetails);
    globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
      detail: { 
        phase: 'init-failed', 
        error: errorMsg, 
        attemptedPaths: pathsToTry,
        lastErrorDetails: lastErrorDetails
      } 
    }));
    throw new Error(errorMsg);
  }

  // Resolve WASM base path
  async function resolveWasmBasePath(wasmBasePath) {
    // Use config paths only - no hardcoded paths
    const wasmPathsToTry = [
      wasmBasePath, // From options
      WASM_BASE_PATH, // From config
    ];
    
    for (const wasmPath of wasmPathsToTry) {
      try {
        const resolvedUrl = resolveModuleUrl(wasmPath);
        const testUrl = `${resolvedUrl}genai_wasm_internal.js`;
        const response = await fetch(testUrl, { method: 'HEAD' });
        if (response.ok) {
          console.log('WASM base path found at:', resolvedUrl);
          return resolvedUrl;
        }
      } catch (error_) {
        // Continue to next path
      }
    }
    
    const fallback = resolveModuleUrl(wasmBasePath);
    console.warn('Using fallback WASM base path:', fallback);
    return fallback;
  }

  // Resolve model asset path
  async function resolveModelAssetPath(modelAssetPath) {
    // Use config paths and normalize the provided path
    const normalizedPaths = [
      modelAssetPath, // Original path from options
      modelAssetPath.startsWith('/') ? modelAssetPath : `/${modelAssetPath}`, // Absolute version
    ];
    
    // Also try the default model path from config if different
    if (modelAssetPath !== MODEL_ASSET_PATH) {
      const configPaths = [
        MODEL_ASSET_PATH,
        MODEL_ASSET_PATH.startsWith('/') ? MODEL_ASSET_PATH : `/${MODEL_ASSET_PATH}`,
      ];
      normalizedPaths.push(...configPaths);
    }
    
    const modelPathsToTry = normalizedPaths;
    
    let modelPathError = null;
    
    for (const path of modelPathsToTry) {
      try {
        const resolvedUrl = resolveModuleUrl(path);
        console.log('Checking model path:', path, '-> resolved to:', resolvedUrl);
        
        const response = await fetch(resolvedUrl, { method: 'HEAD' });
        if (response.ok) {
          console.log('Model file found at:', resolvedUrl);
          return resolvedUrl;
        }
        console.warn(`Model file not accessible at ${resolvedUrl}: ${response.status} ${response.statusText}`);
      } catch (err) {
        console.warn(`Failed to verify model path ${path}:`, err);
        modelPathError = err;
      }
    }
    
    const errorMsg = `Model file not found. Tried paths: ${modelPathsToTry.join(', ')}. Last error: ${modelPathError?.message || 'Unknown'}`;
    console.error(errorMsg);
    globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
      detail: { phase: 'init-failed', error: errorMsg, attemptedPaths: modelPathsToTry } 
    }));
    throw new Error(errorMsg);
  }

  // Create LLM inference with retry logic
  async function createLlmInference(tasks, fileset, baseCreateOptions, cpuOnly) {
    try {
      return await tasks.LlmInference.createFromOptions(fileset, baseCreateOptions);
    } catch (error_) {
      console.error('Initial createFromOptions failed:', error_);
      if (cpuOnly) {
        globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
          detail: { phase: 'init-failed', error: String(error_) } 
        }));
        throw error_;
      }

      console.warn('Retrying createFromOptions forcing CPU backend...');
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
        detail: { phase: 'init-retry-cpu' } 
      }));
      try {
        const cpuOptions = { ...baseCreateOptions, executorBackend: 'CPU', useCpu: true };
        return await tasks.LlmInference.createFromOptions(fileset, cpuOptions);
      } catch (error_) {
        console.error('Retry with CPU failed:', error_);
        globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
          detail: { phase: 'init-failed', error: String(error_) } 
        }));
        throw error_;
      }
    }
  }

  async function init(options) {
    const {
      modelAssetPath = MODEL_ASSET_PATH,
      tasksModulePath = GENAI_BUNDLE_LOCAL_ASSET,
      wasmBasePath = WASM_BASE_PATH,
      cpuOnly = false,
      maxTokens = 1280,
    } = options || {};

    console.log('Initializing MediapipeGenai with options:', options);
    globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-start', options } }));

    if (!('WebAssembly' in globalThis)) {
      console.error('WebAssembly not supported in this browser');
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
        detail: { phase: 'init-failed', error: 'WebAssembly not supported' } 
      }));
      throw new Error('WebAssembly not supported in this browser');
    }

    // Load tasks module
    const tasks = await loadTasksModule(tasksModulePath);

    // Resolve WASM base path
    let resolvedWasmBase = await resolveWasmBasePath(wasmBasePath);
    
    // Check SIMD support
    try {
      console.log('Checking SIMD support for WASM files...');
      await tasks.FilesetResolver.isSimdSupported();
      console.log('SIMD support detected.');
    } catch (err) {
      console.warn('SIMD not supported, using default WASM files:', err);
    }

    console.log('Resolved WASM base path:', resolvedWasmBase);
    const fileset = await tasks.FilesetResolver.forGenAiTasks(resolvedWasmBase);

    // Resolve model asset path
    const resolvedModelPath = await resolveModelAssetPath(modelAssetPath);
    console.log('Creating GenAI task with model asset path:', resolvedModelPath);

    // Build base create options
    const baseCreateOptions = {
      baseOptions: {
        modelAssetPath: resolvedModelPath,
      },
      maxTokens: maxTokens,
    };
    
    if (cpuOnly) {
      baseCreateOptions.executorBackend = 'CPU';
      baseCreateOptions.useCpu = true;
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
        detail: { phase: 'init-info', info: 'Forcing CPU backend as requested' } 
      }));
    }

    // Create LLM inference with retry logic
    llmInference = await createLlmInference(tasks, fileset, baseCreateOptions, cpuOnly);

    console.log('GenAI task successfully created.');
    globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-success' } }));
    return true;
  }

  async function generate(prompt) {
    if (!llmInference) {
      throw new Error('MediapipeGenai not initialized');
    }

    globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'generate-start' } }));

    // Delegate to the underlying LLM inference API
    // The MediaPipe API exposes generateResponse on the LlmInference instance
    try {
      const result = await llmInference.generateResponse(prompt);
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'generate-success', result } }));
      // result may be an object or string depending on the API; normalize to string
      if (typeof result === 'string') return result;
      if (result && typeof result.text === 'string') return result.text;
      // Fallback: stringify
      return JSON.stringify(result);
    } catch (err) {
      console.error('Error generating response from LLM:', err);
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'generate-failed', error: String(err) } }));
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
