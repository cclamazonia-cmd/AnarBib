// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/tests/helpers/compteur-memoire.js
//
// public.fn_compteur_frapper et fn_compteur_rendre (migration 20261019155956),
// rejouées en mémoire pour les bancs d'Edge Functions (19/10/2026). Mêmes règles
// que le SQL, et les deux contraintes de public.auth_rate_limits : `kind` dans
// la liste fermée (auth_rate_limits_kind_check), `key` = empreinte de 64
// hexadécimaux. Une frappe refusée par une contrainte est notée dans `refus` et
// rend l'erreur que rendrait la base.
//
// Usage : const c = compteurEnMemoire();
//         monterEF({ …, rpc: (s, nom, args) => c.rpc(nom, args) ?? autre(nom, args) })
// ═══════════════════════════════════════════════════════════

// = auth_rate_limits_kind_check (dernière définition : 20261019122741)
export const KINDS = ['ip', 'email', 'geocode_user', 'carto_ip', 'gazette_ip', 'gazette_email', 'gazette_prefill', 'bug_ip', 'register_ip', 'register_dest'];

export function compteurEnMemoire({ panne = null } = {}) {
  const lignes = new Map();   // `${kind}|${key}` → { failure_count, first_failure_at, blocked_until } (ms)
  const refus = [];
  const frappes = [];

  function frapper({ p_kind, p_key, p_limite, p_fenetre_min, p_blocage_min }) {
    if (!KINDS.includes(p_kind)) { refus.push({ p_kind, p_key }); return { data: null, error: { code: '23514', message: 'auth_rate_limits_kind_check' } }; }
    if (!/^[0-9a-f]{64}$/.test(String(p_key))) { refus.push({ p_kind, p_key }); return { data: null, error: { code: '23514', message: 'auth_rate_limits_key_empreinte' } }; }
    const maintenant = Date.now();
    const fenetre = p_fenetre_min * 60e3;
    const blocage = (p_blocage_min ?? p_fenetre_min) * 60e3;
    const cle = `${p_kind}|${p_key}`;
    const l = lignes.get(cle);
    let suivante;
    if (!l) {
      suivante = { failure_count: 1, first_failure_at: maintenant, blocked_until: 1 > p_limite ? maintenant + blocage : null };
    } else if (l.blocked_until && l.blocked_until > maintenant) {
      suivante = l;
    } else if (!l.blocked_until && l.first_failure_at > maintenant - fenetre) {
      const n = l.failure_count + 1;
      suivante = { failure_count: n, first_failure_at: l.first_failure_at, blocked_until: n > p_limite ? maintenant + blocage : null };
    } else {
      suivante = { failure_count: 1, first_failure_at: maintenant, blocked_until: 1 > p_limite ? maintenant + blocage : null };
    }
    lignes.set(cle, suivante);
    frappes.push({ p_kind, p_key });
    return { data: !!(suivante.blocked_until && suivante.blocked_until > maintenant), error: null };
  }

  function rendre({ p_kind, p_key }) {
    const l = lignes.get(`${p_kind}|${p_key}`);
    if (l && !(l.blocked_until && l.blocked_until > Date.now())) l.failure_count = Math.max(l.failure_count - 1, 0);
    return { data: null, error: null };
  }

  return {
    lignes, refus, frappes,
    /** La réponse d'une RPC de compteur, ou undefined si `nom` n'en est pas une. */
    rpc(nom, args) {
      if (nom !== 'fn_compteur_frapper' && nom !== 'fn_compteur_rendre') return undefined;
      if (panne) return { data: null, error: panne };
      return nom === 'fn_compteur_frapper' ? frapper(args) : rendre(args);
    },
  };
}
