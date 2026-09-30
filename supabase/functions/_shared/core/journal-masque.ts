// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : supabase/functions/_shared/core/journal-masque.ts
//
// Aucune adresse de courriel en clair dans les journaux (backlog F19, 30/09/2026).
//
// La carte de la chaîne de courriel (F1) a relevé, dans les journaux des fonctions
// Edge, des lignes « [user_mail] sent to <adresse> » et « failed for <adresse> »
// depuis au moins le 04/08 : toute personne qui ouvre les journaux lisait les
// adresses des lectrices et du staff. Les journaux sont un outil de diagnostic ;
// une adresse n'y sert à rien que « est-ce parti ? » ne dise déjà.
//
// Deux gestes :
//   · `masquerAdresse` / `masquerAdresses`, appelés explicitement là où l'on
//     journalise un destinataire (transport, notifieurs) : « a…@domaine » —
//     la première lettre et le domaine, assez pour compter et pour voir un
//     fournisseur qui rebondit, pas assez pour identifier ;
//   · un filet : au chargement, sous Deno, `console.log/info/warn/error/debug`
//     passent leurs arguments au même masque — une adresse glissée dans un objet
//     d'erreur (un « Key (email)=(…) already exists » de Postgres, une ligne de
//     file imprimée entière) ne sort plus en clair. Chaque fonction Edge y arrive
//     par `deps.ts` ou par la couche d'envoi ; le banc
//     src/tests/journal-sans-adresse.test.js vérifie qu'aucune n'y échappe.
// ═══════════════════════════════════════════════════════════

const ADRESSE = /([A-Za-z0-9._%+-])[A-Za-z0-9._%+-]*@((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,})/g;

/** Masque toutes les adresses d'un texte : « lectrice@exemple.org » → « l…@exemple.org ». */
export function masquerAdresses(texte: unknown): string {
  return String(texte ?? '').replace(ADRESSE, (_m, premier, domaine) => `${premier}…@${domaine}`);
}

/** Masque une adresse (ou une liste jointe) avant de la journaliser. */
export function masquerAdresse(adresse: unknown): string {
  const s = String(adresse ?? '').trim();
  return s ? masquerAdresses(s) : s;
}

function versJournal(a: unknown, inspecter?: (v: unknown) => string): unknown {
  if (typeof a === 'string') return masquerAdresses(a);
  if (a === null || a === undefined || typeof a === 'number' || typeof a === 'boolean' || typeof a === 'bigint') return a;
  try {
    if (inspecter) return masquerAdresses(inspecter(a));
    if (a instanceof Error) return masquerAdresses(`${a.name}: ${a.message}${a.stack ? `\n${a.stack}` : ''}`);
    return masquerAdresses(JSON.stringify(a));
  } catch {
    return '[objet non journalisable]';
  }
}

const MARQUE = Symbol.for('anarbib.journal.masque');

/** Enveloppe les méthodes d'un objet console ; sans effet la seconde fois. */
export function installerMasque(c: Record<string | symbol, unknown>, inspecter?: (v: unknown) => string): void {
  if (!c || c[MARQUE]) return;
  for (const m of ['log', 'info', 'warn', 'error', 'debug']) {
    const orig = c[m];
    if (typeof orig !== 'function') continue;
    const lie = (orig as (...a: unknown[]) => void).bind(c);
    c[m] = (...args: unknown[]) => lie(...args.map((a) => versJournal(a, inspecter)));
  }
  c[MARQUE] = true;
}

// Installé au chargement dans les fonctions Edge (Deno) seulement : sous Node,
// le banc l'éprouve par `installerMasque` sur une fausse console, sans toucher
// à celle de vitest.
// deno-lint-ignore no-explicit-any
const D = (globalThis as any).Deno;
if (D && typeof D.inspect === 'function') {
  installerMasque(console as unknown as Record<string | symbol, unknown>, (v) => D.inspect(v, { depth: 6, colors: false }));
}
