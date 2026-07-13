// Service worker compartido por las 3 apps de IwolPark (Cajero/Admin/Corporativo).
// Solo cachea el shell (el propio HTML de cada app, que ya trae todo su CSS/JS
// inline) para que abra offline tras la primera visita. Los datos operativos
// (tickets, cortes, cajeros, bitácora) siempre van directo a Supabase — nunca
// se cachean, porque el sync offline-first ya lo maneja IndexedDB en cada app.
const CACHE_NAME = 'iwolpark-shell-v3';
const SHELL_FILES = [
  'IwolPark_TABLET.html',
  'IwolPark_Dashboard_Admin.html',
  'IwolPark_Dashboard_Corporativo.html',
  'manifest_tablet.json',
  'manifest_admin.json',
  'manifest_corporativo.json',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(SHELL_FILES))
      .catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  // Solo GET del mismo origen (el shell). Todo lo demás — y en particular
  // cualquier llamada a Supabase, que es otro origen — pasa de largo sin
  // que el service worker la toque.
  if (url.origin !== self.location.origin || event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      const enRed = fetch(event.request).then((resp) => {
        if (resp && resp.ok) {
          const copia = resp.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copia));
        }
        return resp;
      }).catch(() => cached);
      // Responde con lo cacheado de inmediato si existe (rápido y funciona
      // offline) y de todos modos actualiza el caché en segundo plano.
      return cached || enRed;
    })
  );
});
