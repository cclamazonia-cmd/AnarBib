// ═══════════════════════════════════════════════════════════════════════════
// Solveur Altcha — tourne dans un Web Worker
// ═══════════════════════════════════════════════════════════════════════════
//
// Cherche par force brute le nombre n tel que sha256(salt + n) === challenge.
// Dans un worker, et pas sur le fil principal : une demi-seconde de calcul
// bloquant gèlerait le formulaire, y compris le bouton d'annulation.
//
// Rend compte de sa progression pour que l'interface montre quelque chose —
// une barre qui avance vaut mieux qu'un bouton qui ne répond pas.
// ═══════════════════════════════════════════════════════════════════════════

import { sha256HexAscii } from './sha256.js';

self.onmessage = (e) => {
  const { salt, challenge, maxnumber } = e.data || {};
  if (typeof salt !== 'string' || typeof challenge !== 'string') {
    self.postMessage({ type: 'error', motif: 'defi_invalide' });
    return;
  }
  const max = Number(maxnumber) || 300000;
  const pas = Math.max(1, Math.floor(max / 50));
  const t0 = Date.now();

  for (let n = 0; n <= max; n++) {
    if (sha256HexAscii(salt + n) === challenge) {
      self.postMessage({ type: 'ok', number: n, ms: Date.now() - t0 });
      return;
    }
    if (n % pas === 0) self.postMessage({ type: 'progres', ratio: n / max });
  }
  // Le serveur tire toujours son nombre dans [0, max] : ne rien trouver
  // signifie un défi corrompu en transit, pas une malchance.
  self.postMessage({ type: 'error', motif: 'sans_solution' });
};
