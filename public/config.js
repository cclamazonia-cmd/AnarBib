// =============================================================================
// AnarBib — Configuration d'exécution dynamique (Zero-Build)
// =============================================================================
// En mode conteneurisé Zero-Build, ce fichier est réécrit au démarrage du conteneur
// Caddy/web (/srv/config.js) pour injecter la clé anonyme (ANON_KEY) propre à l'instance.
// En mode développement ou déploiement classique dist/, ce fichier sert d'objet de repli neutre.
// =============================================================================
window.__ANARBIB_CONFIG__ = window.__ANARBIB_CONFIG__ || {};
