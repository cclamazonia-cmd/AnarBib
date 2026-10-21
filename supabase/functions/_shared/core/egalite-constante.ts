// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : supabase/functions/_shared/core/egalite-constante.ts
//
// Comparer un secret reçu au secret attendu sans que la durée de la comparaison
// dise jusqu'où ils coïncident (21/10/2026). `a === b` s'arrête au premier
// caractère différent : mesurée sur assez d'essais, sa durée trahit la longueur
// du préfixe juste, de quoi reconstruire un secret caractère par caractère.
// Onze fonctions comparaient ainsi leur secret de tâche ou de webhook.
//
//   · secretValide(attendu, recu) : faux si l'attendu est vide (un secret non
//     configuré n'ouvre jamais rien), faux si rien n'est reçu, sinon la
//     comparaison à durée constante ;
//   · egaliteConstante(a, b) : parcourt toujours la plus longue des deux
//     chaînes ; la longueur seule peut se lire, pas le contenu.
//
// Sans dépendance à Deno : chargé tel quel par vitest
// (src/tests/egalite-constante.test.js).
// ═══════════════════════════════════════════════════════════

export function egaliteConstante(a: string, b: string): boolean {
  const x = String(a ?? '');
  const y = String(b ?? '');
  const n = Math.max(x.length, y.length);
  let diff = x.length ^ y.length;
  for (let i = 0; i < n; i++) diff |= (x.charCodeAt(i) || 0) ^ (y.charCodeAt(i) || 0);
  return diff === 0;
}

export function secretValide(attendu: string | null | undefined, recu: string | null | undefined): boolean {
  const a = String(attendu ?? '').trim();
  const r = String(recu ?? '').trim();
  if (!a || !r) return false;
  return egaliteConstante(a, r);
}
