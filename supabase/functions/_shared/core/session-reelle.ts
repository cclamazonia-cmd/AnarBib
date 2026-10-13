// ═══════════════════════════════════════════════════════════
// AnarBib — B44 (13/10/2026) : « l'appelant a-t-il une vraie session ? »,
// demandé à la base sous le jeton de l'appelant.
//
// verify_jwt = true ne l'exige PAS. Mesuré en prod le 13/10 (B43) : un POST
// avec la seule clé publiable, sans en-tête Authorization, atteint le code de
// la fonction ; la passerelle ne refuse que les JWT mal formés. Les fonctions
// qui interrogent des services tiers (métadonnées, capas, autorités, portraits,
// géocodage, empreintes audio, pages web) sans rien demander d'abord sous le
// jeton de l'appelant étaient donc des relais ouverts à tout Internet : quotas
// et clés d'API du projet, adresse IP du projet bannie, PDF de 30 Mo relayés.
//
// La preuve : api.fn_mon_etat_double_facteur, appelée sous le jeton de
// l'appelant. Elle lève 42501 quand auth.uid() est nul, et anon n'a pas le
// droit de l'exécuter : un jeton anon, la clé publiable, un en-tête absent ou
// faux ne passent pas. Elle dit en même temps si la session doit présenter le
// second facteur (B42) : ces fonctions ne font aucune requête sous le jeton de
// l'appelant, la fonction d'avant-requête de PostgREST ne les voit jamais, la
// garde le fait à sa place. Un seul aller-retour, la règle reste dans la base.
//
// ÉCHEC FERMÉ : seule une réponse lisible ouvre. Une erreur, un corps
// inattendu, le réseau, un en-tête absent : on refuse.
//
// Sans dépendance à Deno : chargé tel quel par vitest
// (src/tests/session-reelle-relais.test.js), fetch injectable.
// ═══════════════════════════════════════════════════════════

/** Les codes de refus des fonctions (error.edge.* dans les dix locales). */
export type RefusSession = 'auth_required' | 'aal2_required';

/** Le statut HTTP d'un refus : 401 sans session, 403 sans second facteur. */
export const statutDuRefus = (refus: RefusSession): number => (refus === 'aal2_required' ? 403 : 401);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * L'identifiant du compte (`sub`) porté par le jeton de l'appelant, ou null.
 * B45 : le compteur de geocode compte par compte, plus par adresse IP.
 * À n'appeler qu'APRÈS sessionManquante → null : ce jeton-là vient alors
 * d'être accepté par PostgREST (signature et expiration vérifiées), lire son
 * `sub` sans revérifier la signature est sûr. Avant, n'importe qui pourrait y
 * écrire n'importe quoi.
 */
export function sujetDuJeton(authHeader: string | null | undefined): string | null {
  const m = String(authHeader || '').match(/^bearer\s+([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/i);
  if (!m) return null;
  try {
    const b64 = m[2].replace(/-/g, '+').replace(/_/g, '/');
    const charge = JSON.parse(atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4)));
    return typeof charge?.sub === 'string' && UUID.test(charge.sub) ? charge.sub.toLowerCase() : null;
  } catch {
    return null;
  }
}

/**
 * null quand l'appelant a une session d'usager réelle (et le second facteur si
 * son compte le doit) ; sinon le code du refus.
 * @param supabaseUrl  SUPABASE_URL
 * @param anonKey      clé publique (SUPABASE_ANON_KEY)
 * @param authHeader   l'en-tête Authorization de l'appelant, tel quel
 */
export async function sessionManquante(
  supabaseUrl: string | undefined,
  anonKey: string | undefined,
  authHeader: string | null | undefined,
  fetchFn: typeof fetch = fetch,
): Promise<RefusSession | null> {
  if (!supabaseUrl || !anonKey || !authHeader) return 'auth_required';
  if (!/^bearer\s+\S+/i.test(authHeader)) return 'auth_required';
  try {
    const res = await fetchFn(`${supabaseUrl}/rest/v1/rpc/fn_mon_etat_double_facteur`, {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: authHeader,
        'Accept-Profile': 'api',
        'Content-Profile': 'api',
        'Content-Type': 'application/json',
      },
      body: '{}',
    });
    if (!res.ok) return 'auth_required';
    const etat = await res.json();
    if (!etat || typeof etat !== 'object' || typeof etat.exige !== 'boolean' || typeof etat.aal !== 'string') {
      return 'auth_required';
    }
    return etat.exige && etat.aal !== 'aal2' ? 'aal2_required' : null;
  } catch {
    return 'auth_required';
  }
}
