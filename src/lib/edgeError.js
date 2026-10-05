// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — src/lib/edgeError.js
//
// E24 (05/10/2026) : le refus d'une Edge Function, traduisible.
//
// Une fonction qui refuse rend { error, code } — `error` est un texte de repli,
// écrit dans une seule langue ; `code` est stable. Quand le refus vient de la
// base, elle relaie aussi le `hint` de la RPC (clé error.*, E23). Cette aide en
// fait une Error que localizeError sait traduire : le hint de la base d'abord,
// sinon la clé error.edge.<code> (dix locales), sinon le texte de repli.
//
// Modèle : la fonction `login` (3cf927e1), dont l'écran traduit les codes.
// ─────────────────────────────────────────────────────────────────────────────

export const EDGE_KEY_PREFIX = 'error.edge.';

export function erreurDeFonction(out, status) {
  const corps = out && typeof out === 'object' ? out : {};
  const err = new Error(typeof corps.error === 'string' && corps.error ? corps.error : `HTTP ${status}`);
  if (typeof corps.hint === 'string' && corps.hint.startsWith('error.')) err.hint = corps.hint;
  else if (typeof corps.code === 'string' && /^[a-z][a-z0-9_]*$/.test(corps.code)) err.hint = EDGE_KEY_PREFIX + corps.code;
  if (typeof corps.code === 'string') err.edgeCode = corps.code;
  if (status) err.status = status;
  return err;
}
