const CACHE_NAME = 'medicoai-cache-v1';
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/mediapipe_text.js',
  '/assets/mediapipe/genai_bundle.mjs',
  '/assets/mediapipe/wasm/genai_wasm_internal.js',
  '/assets/mediapipe/wasm/genai_wasm_internal.wasm',
  '/assets/mediapipe/wasm/genai_wasm_nosimd_internal.js',
  '/assets/mediapipe/wasm/genai_wasm_nosimd_internal.wasm',
  '/assets/models/gemma3-1b-it-int8-web.task',
  '/assets/models/Gemma3-1B.task',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      // Serve cached response if available, otherwise fetch from network
      return response || fetch(event.request);
    })
  );
});
