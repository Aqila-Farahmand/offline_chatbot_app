// Single canonical path for MediaPipe GenAI bundle (matches path_configs.dart)
// Flutter web serves assets from /assets/ in both debug and release modes
export const GENAI_BUNDLE_PATH = '/assets/mediapipe/genai_bundle.mjs';

// Single canonical path for WASM base directory (matches path_configs.dart)
export const WASM_BASE_PATH = '/assets/mediapipe/wasm';

// Single canonical path for model assets (matches path_configs.dart)
export const MODEL_ASSET_PATH = '/assets/models/';

// Note: node_modules export removed - app uses bundled genai_bundle.mjs instead
// If you need to regenerate the bundle, you can temporarily add:
// export const node_modules = {
//   '@mediapipe/tasks-genai': './node_modules/@mediapipe/tasks-genai/',
// };
