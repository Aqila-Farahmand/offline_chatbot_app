// Bridge to MediaPipe Tasks Genai for local inference on web.
import {
  GENAI_BUNDLE_PATH,
  WASM_BASE_PATH,
  MODEL_ASSET_PATH,
} from './config/config.js';

// Expose a plain object on a globalThis.MediapipeGenai with async methods init, generate, dispose
globalThis.MediapipeGenai = (function () {
  let llmInference = null;

  // Helper function to resolve URL - uses single consistent path resolution
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

  // Load the MediaPipe Tasks GenAI module - uses single path from config
  async function loadTasksModule(tasksModulePath) {
    // Use the path from options, or fall back to config default
    const pathToUse = tasksModulePath || GENAI_BUNDLE_PATH;
    
    // Normalize path: ensure it starts with /assets/ for consistency
    let normalizedPath = pathToUse;
    if (!normalizedPath.startsWith('/assets/')) {
      if (normalizedPath.startsWith('assets/')) {
        normalizedPath = `/${normalizedPath}`;
      } else {
        normalizedPath = `/assets/${normalizedPath.replace(/^\/?/, '')}`;
      }
    }
    
    const moduleUrl = resolveModuleUrl(normalizedPath);
    console.log('Loading MediaPipe Tasks module from:', normalizedPath, '-> resolved to:', moduleUrl);
    
    try {
      const tasks = await import(moduleUrl);
      console.log('Successfully loaded MediaPipe Tasks module');
      return tasks;
    } catch (err) {
      const errorMsg = `Failed to load MediaPipe Tasks Genai module from ${normalizedPath}: ${err.message || err}`;
      console.error(errorMsg, err);
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
        detail: { 
          phase: 'init-failed', 
          error: errorMsg,
          path: normalizedPath,
          resolvedUrl: moduleUrl
        } 
      }));
      throw new Error(errorMsg);
    }
  }

  // Resolve WASM base path - uses single path from config
  async function resolveWasmBasePath(wasmBasePath) {
    // Use the path from options, or fall back to config default
    const pathToUse = wasmBasePath || WASM_BASE_PATH;

    // Normalize path: ensure it starts with /assets/ and has NO trailing slash
    let normalizedPath = pathToUse;
    if (!normalizedPath.startsWith('/assets/')) {
      if (normalizedPath.startsWith('assets/')) {
        normalizedPath = `/${normalizedPath}`;
      } else {
        normalizedPath = `/assets/${normalizedPath.replace(/^\/?/, '')}`;
      }
    }
    // Strip any trailing slashes to avoid // in downstream loaders
    normalizedPath = normalizedPath.replace(/\/+$/, '');

    const resolvedUrl = resolveModuleUrl(normalizedPath);
    console.log('Using WASM base path:', normalizedPath, '-> resolved to:', resolvedUrl);
    return resolvedUrl;
  }

  // Resolve model asset path - uses single path from config
  async function resolveModelAssetPath(modelAssetPath) {
    // Normalize path: ensure it starts with /assets/
    let normalizedPath = modelAssetPath;
    
    if (!normalizedPath.startsWith('/assets/')) {
      if (normalizedPath.startsWith('assets/')) {
        normalizedPath = `/${normalizedPath}`;
      } else if (normalizedPath.startsWith('models/')) {
        normalizedPath = `/assets/${normalizedPath}`;
      } else {
        normalizedPath = `/assets/models/${normalizedPath.replace(/^\/?/, '')}`;
      }
    }
    
    const resolvedUrl = resolveModuleUrl(normalizedPath);
    console.log('Using model path:', normalizedPath, '-> resolved to:', resolvedUrl);
    return resolvedUrl;
  }

  // Create LLM inference with retry logic
  async function createLlmInference(tasks, fileset, baseCreateOptions, cpuOnly) {
    console.log('Creating LLM inference with options:', baseCreateOptions);
    try {
      console.log('Calling LlmInference.createFromOptions...');
      const startTime = Date.now();
      const createPromise = tasks.LlmInference.createFromOptions(fileset, baseCreateOptions);
      console.log('createFromOptions promise created, awaiting...');
      
      // Log progress periodically while waiting
      const progressInterval = setInterval(() => {
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        if (elapsed % 5 === 0) { // Log every 5 seconds
          console.log(`Still waiting for createFromOptions... (${elapsed}s elapsed)`);
        }
      }, 1000);
      
      // MediaPipe's createFromOptions can take a while, especially on first load
      // Wait up to 75 seconds (Dart timeout is 90s, giving some buffer)
      const inference = await Promise.race([
        createPromise,
        new Promise((_, reject) => {
          setTimeout(() => {
            clearInterval(progressInterval);
            console.error('createFromOptions timed out after 75 seconds');
            console.error('Note: Graph may have started (check console for "Graph successfully started running")');
            reject(new Error('createFromOptions timed out after 75 seconds. Graph may have started but promise did not resolve.'));
          }, 75000);
        })
      ]);
      
      clearInterval(progressInterval);
      const elapsed = Math.round((Date.now() - startTime) / 1000);
      console.log(`createFromOptions completed in ${elapsed} seconds`);
      console.log('LLM inference created successfully, type:', typeof inference);
      
      // Verify inference object
      if (!inference) {
        throw new Error('createFromOptions returned null/undefined');
      }
      
      return inference;
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
        const startTime = Date.now();
        const createPromise = tasks.LlmInference.createFromOptions(fileset, cpuOptions);
        
        // Log progress for retry too
        const progressInterval = setInterval(() => {
          const elapsed = Math.round((Date.now() - startTime) / 1000);
          if (elapsed % 5 === 0) {
            console.log(`Still waiting for createFromOptions (CPU)... (${elapsed}s elapsed)`);
          }
        }, 1000);
        
        const inference = await Promise.race([
          createPromise,
          new Promise((_, reject) => {
            setTimeout(() => {
              clearInterval(progressInterval);
              console.error('createFromOptions (CPU) timed out after 75 seconds');
              reject(new Error('createFromOptions (CPU) timed out after 75 seconds'));
            }, 75000);
          })
        ]);
        
        clearInterval(progressInterval);
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        console.log(`createFromOptions (CPU) completed in ${elapsed} seconds`);
        console.log('LLM inference created successfully with CPU backend');
        return inference;
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
    try {
      const {
        modelAssetPath = MODEL_ASSET_PATH,
        tasksModulePath = GENAI_BUNDLE_PATH,
        wasmBasePath = WASM_BASE_PATH,
        cpuOnly = false,
        maxTokens = 1280, // Default matches LLMConfig.defaultMaxTokens
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
      console.log('Step 1: Loading MediaPipe Tasks module...');
      const tasks = await loadTasksModule(tasksModulePath);

      // Resolve WASM base path
      console.log('Step 2: Resolving WASM base path...');
      let resolvedWasmBase = await resolveWasmBasePath(wasmBasePath);
      
      // Check SIMD support
      try {
        console.log('Checking SIMD support for WASM files...');
        await tasks.FilesetResolver.isSimdSupported();
        console.log('SIMD support detected.');
      } catch (err) {
        console.warn('SIMD not supported, using default WASM files:', err);
      }

      console.log('Step 3: Creating FilesetResolver...');
      const fileset = await tasks.FilesetResolver.forGenAiTasks(resolvedWasmBase);

      // Resolve model asset path
      console.log('Step 4: Resolving model asset path...');
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
      console.log('Step 5: Creating LLM inference task...');
      
      // Directly call createLlmInference - it has its own timeout handling
      llmInference = await createLlmInference(tasks, fileset, baseCreateOptions, cpuOnly);

      // Verify the inference object was created
      if (!llmInference) {
        throw new Error('Failed to create LLM inference object - createFromOptions returned null/undefined');
      }

      console.log('Step 6: LLM inference object created, verifying methods...');
      
      // Verify the inference object has the required methods
      if (typeof llmInference.generateResponse !== 'function') {
        throw new TypeError('LLM inference object missing generateResponse method');
      }

      // Wait a brief moment to ensure the graph is fully initialized
      console.log('Step 7: Waiting for graph to fully initialize...');
      await new Promise(resolve => setTimeout(resolve, 500));

      console.log('✅ GenAI task successfully created and initialized.');
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { detail: { phase: 'init-success' } }));
      return true;
    } catch (error) {
      console.error('❌ MediapipeGenai.init failed:', error);
      globalThis.dispatchEvent(new CustomEvent('MediapipeGenaiStatus', { 
        detail: { phase: 'init-failed', error: String(error) } 
      }));
      throw error;
    }
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
