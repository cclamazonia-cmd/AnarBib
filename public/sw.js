/* =========================================================================
 * AnarBib — Service Worker (socle PWA, MOBILE Paquet 0)
 * =========================================================================
 * Cadre : chantier « Extension mobile / Mode terrain », décision doctrinale 3
 *   (DECISION_chantier_mobile_arbitrages_2026-05-28) :
 *   « Le mobile AnarBib est une PWA mono-codebase ; service worker et
 *     stratégie de cache : SANS TRACKER, à documenter explicitement. »
 *
 * STRATÉGIE DE CACHE — documentée explicitement (exigence doctrinale)
 * -------------------------------------------------------------------------
 *   • On NE met en cache QUE les ressources SAME-ORIGIN en GET (le « shell »
 *     de l'app servi par app.anarbib.org : index.html, JS/CSS/polices/icônes).
 *   • On N'INTERCEPTE JAMAIS l'API ni le Storage Supabase (cross-origin :
 *     *.supabase.co), ni l'auth, ni aucune requête non-GET. Donc :
 *       - aucun token, aucune donnée personnelle, aucune réponse d'API n'entre
 *         jamais en cache (vie privée + fraîcheur garanties) ;
 *       - pas de risque de servir des données périmées/privées hors-ligne.
 *   • Aucune télémétrie, aucun appel tiers : ce SW ne « tracke » rien.
 *
 *   Stratégies par type de requête same-origin :
 *     - Navigation (chargement de page) : NETWORK-FIRST → repli sur le shell
 *       en cache si hors-ligne (l'app cliente route ensuite côté client).
 *     - Asset statique (JS/CSS/police/image) : STALE-WHILE-REVALIDATE
 *       (sert le cache immédiatement, rafraîchit en arrière-plan).
 *
 * LIMITE CONNUE (P0) : pas de pré-cache exhaustif des assets hashés au build.
 *   Le shell hors-ligne est donc disponible APRÈS une première visite en ligne
 *   (les assets se mettent en cache au fil des requêtes). Un pré-cache complet
 *   (vite-plugin-pwa) reste un raffinement possible si l'offline-first strict
 *   devient nécessaire (P3 permanence). Suffisant pour P0 (installable + shell).
 *
 * Déploiement : fichier statique servi tel quel par Codeberg Pages. Bump la
 *   version du cache (CACHE) lors d'un changement de stratégie pour invalider.
 * ========================================================================= */

const CACHE = 'anarbib-shell-v1';
const SHELL = ['/', '/manifest.webmanifest', '/img/icon-192.png', '/img/icon-512.png'];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Tolérant : un asset manquant ne doit pas faire échouer toute l'install.
    await Promise.allSettled(SHELL.map((url) => cache.add(url)));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Garde-fou central : ne traiter QUE le same-origin en GET.
  // Tout le reste (API/Storage Supabase cross-origin, POST/PUT/DELETE, etc.)
  // n'est pas intercepté → réseau normal, jamais mis en cache.
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;

  // Navigation : network-first, repli shell hors-ligne.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).catch(() => caches.match('/').then((r) => r || Response.error()))
    );
    return;
  }

  // Asset statique same-origin : stale-while-revalidate.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(req);
    const network = fetch(req).then((res) => {
      if (res && res.status === 200 && res.type === 'basic') {
        cache.put(req, res.clone());
      }
      return res;
    }).catch(() => cached);
    return cached || network;
  })());
});
