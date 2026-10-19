// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/tests/helpers/cle-compteur.js
//
// L'empreinte qu'attend public.auth_rate_limits pour une valeur, calculée par
// Node comme _shared/core/rate-limit.ts la calcule sous Deno (19/10/2026) :
// HMAC-SHA256 sous une clé dérivée de la clé secrète du projet (étiquette
// « anarbib/compteurs-d-abus/v1 »). `secret` vaut par défaut la clé « default »
// d'ENV_BASE (helpers/monter-ef.js).
// ═══════════════════════════════════════════════════════════

import { createHmac } from 'node:crypto';

export function cleCompteur(valeur, secret = 'stub') {
  const derivee = createHmac('sha256', secret).update('anarbib/compteurs-d-abus/v1').digest();
  return createHmac('sha256', derivee).update(String(valeur)).digest('hex');
}
