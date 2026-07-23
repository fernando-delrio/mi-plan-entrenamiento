// Service worker mínimo: solo cachea el "shell" propio (este archivo, index.html,
// manifest, icono) para que la app abra aunque la conexión falle un momento —
// por ejemplo en mitad de una ruta de enduro. Los scripts de CDN (React,
// Babel, Supabase) y las llamadas a Supabase se dejan pasar directo a la red:
// interceptarlos añadiría complejidad (respuestas opacas cross-origin) sin
// aportar offline real, ya que Tutorial IA/vídeos/datos siempre necesitan
// conexión — eso ya se avisa en la propia guía de Publicar.
const CACHE_NAME = "plan-definitivo-v1";
const SHELL_FILES = ["./", "./index.html", "./manifest.json", "./icon.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_FILES)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  event.respondWith(caches.match(event.request).then((cached) => cached || fetch(event.request)));
});
