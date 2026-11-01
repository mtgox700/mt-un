// Service worker uniion : installation et ouverture hors ligne de l'application elle-même.
// AUCUNE donnée métier n'est mise en cache : seules les ressources statiques de ce domaine
// (code, styles, polices, extensions signées). L'API (autre domaine) n'est jamais interceptée.
const VERSION = 'uniion-v1';
const COQUE = ['/', '/index.html', '/tokens.css', '/uniion-logo.png', '/manifest.webmanifest'];
const STATIQUE = /^\/(assets|fonts|ext)\//;

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(COQUE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((k) => Promise.all(k.filter((n) => n !== VERSION).map((n) => caches.delete(n)))).then(() => self.clients.claim()));
});
self.addEventListener('message', (e) => {
  if (e.data === 'purger') e.waitUntil(caches.delete(VERSION));  // déconnexion
});
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (e.request.mode === 'navigate') {
    // Réseau d'abord ; hors ligne, la coque s'ouvre et affiche l'état « hors ligne ».
    e.respondWith(fetch(e.request).catch(() => caches.match('/index.html')));
    return;
  }
  if (STATIQUE.test(url.pathname) || COQUE.includes(url.pathname)) {
    // Fichiers versionnés par leur nom : cache d'abord.
    e.respondWith(caches.match(e.request).then((r) => r || fetch(e.request).then((rep) => {
      if (rep.ok) { const copie = rep.clone(); caches.open(VERSION).then((c) => c.put(e.request, copie)); }
      return rep;
    })));
  }
});
