const CACHE_NAME = 'medicoai-cache-v2';
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
  // Activate updated SW immediately
  self.skipWaiting();
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
  // Take control of uncontrolled clients ASAP
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  const isCritical = url.pathname.endsWith('.mjs')
    || url.pathname.endsWith('.js')
    || url.pathname.endsWith('.wasm');

  // Prefer network for critical assets to avoid stale SW-cached code during dev
  if (isCritical) {
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          return caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, networkResponse.clone());
            return networkResponse;
          });
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // Default: cache-first
  event.respondWith(caches.match(event.request).then((response) => response || fetch(event.request)));
});
