// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/lib/volumes.js
//
// Deux notices qui portent des numéros de volume DIFFÉRENTS ne sont pas des
// doublons, même sous un seul ISBN : l'ISBN d'un ensemble est porté par chacun
// de ses volumes (27/09/2026 : BTL-TL-000447 et BTL-TL-000448, volumes 2 et 3
// de « La C.N.T. y la Revolución Española », même ISBN).
//
// Même règle que publish_book_draft (migration 20260927164619) : casse et
// espaces ignorés ; un volume absent d'un côté ne prouve rien — on ne sait pas
// alors que c'est un ensemble.
// ═══════════════════════════════════════════════════════════

const normer = (v) => String(v ?? '').trim().toLowerCase();

/** Vrai seulement si les deux volumes sont renseignés ET différents. */
export function volumesDifferents(a, b) {
  const x = normer(a);
  const y = normer(b);
  return x !== '' && y !== '' && x !== y;
}
