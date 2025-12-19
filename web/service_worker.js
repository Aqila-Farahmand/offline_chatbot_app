const CACHE_NAME = 'medicoai-cache-v2';
// Only cache small, essential files during install
// Large files (WASM, models) will be cached on-demand during fetch
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/mediapipe_text.js',
  '/assets/mediapipe/genai_bundle.mjs',
  '/assets/mediapipe/wasm/genai_wasm_internal.js',
  '/assets/mediapipe/wasm/genai_wasm_nosimd_internal.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Use addAll but handle individual failures gracefully
      return Promise.allSettled(
        ASSETS_TO_CACHE.map((url) =>
          cache.add(url).catch((err) => {
            console.warn(`Service Worker: Failed to cache ${url}:`, err);
            return null; // Continue even if one asset fails
          })
        )
      );
    }).catch((err) => {
      console.error('Service Worker: Failed to open cache during install:', err);
      // Don't fail installation if cache fails
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
    || url.pathname.endsWith('.wasm')
    || url.pathname.endsWith('.task'); // Include model files

  // Prefer network for critical assets to avoid stale SW-cached code during dev
  if (isCritical) {
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          // Only cache if response is cacheable (not opaque from CORS)
          // For WASM and model files, we need to check if they're cacheable
          if (networkResponse.status === 200 && networkResponse.type === 'basic') {
            return caches.open(CACHE_NAME).then((cache) => {
              // Cache in background, don't block on errors
              // Large files (WASM, models) may fail to cache - that's OK
              cache.put(event.request, networkResponse.clone()).catch((err) => {
                // Silently ignore cache errors for large binary files
                // They'll be fetched from network on next request
                if (!url.pathname.endsWith('.wasm') && !url.pathname.endsWith('.task')) {
                  console.warn('Service Worker: Failed to cache resource:', event.request.url, err);
                }
              });
              return networkResponse;
            }).catch((err) => {
              // If cache open fails, still return the response
              console.warn('Service Worker: Failed to open cache:', err);
              return networkResponse;
            });
          }
          // For opaque responses (CORS), don't try to cache
          return networkResponse;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // Default: cache-first
  event.respondWith(caches.match(event.request).then((response) => response || fetch(event.request)));
});
