// ═══════════════════════════════════════════════════════════
// AnarBib — B42, lot 3 (13/10/2026) : la double authentification dans les
// Edge Functions qui travaillent avec la clé de service.
//
// La fonction d'avant-requête de PostgREST (private.fn_avant_requete) refuse
// toute requête faite avec le jeton d'une session aal1 dont le compte doit
// être en aal2. Une Edge Function dont la PREMIÈRE requête part sous le jeton
// de l'appelant est donc couverte. Une fonction qui lit ou écrit à la clé de
// service AVANT de faire quoi que ce soit sous ce jeton passe à côté : elle
// demande l'état au serveur, par la seule RPC que la liste blanche laisse
// passer (api.fn_mon_etat_double_facteur), avec le jeton de l'appelant. La
// règle reste écrite à un seul endroit, la base (mode off / facteurs /
// equipes).
//
// Audit du 13/10 (B42 lot 3) : une seule fonction dans ce cas,
// attach-received-asset. Les autres font leur première requête sous le jeton
// de l'appelant (deposit-fonds-direct, export-fonds-bundle,
// export-catalog-lote, read-digital-asset, read-ill-shared-asset,
// revoke-digital-asset, notify-library-invitation) ou n'ont pas de session
// d'usager (secret de tâche, formulaires publics, login, register,
// request-password-reset).
//
// ÉCHEC FERMÉ, à l'inverse de la fonction d'avant-requête : ici l'appelant est
// connecté et une seule fonction est en jeu. Un état illisible (RPC absente,
// réseau, jeton refusé) ne prouve rien : on refuse.
//
// Sans dépendance à Deno : chargé tel quel par vitest
// (src/tests/double-facteur-fonctions.test.js), fetch injectable.
// ═══════════════════════════════════════════════════════════

/** Le code de refus des fonctions (error.edge.aal2_required dans les dix locales). */
export const CODE_AAL2 = 'aal2_required';

/**
 * Vrai quand la session de l'appelant n'a pas prouvé le second facteur que son
 * compte doit présenter — ou quand l'état ne se lit pas.
 * @param supabaseUrl  SUPABASE_URL
 * @param anonKey      clé publique (SUPABASE_ANON_KEY)
 * @param authHeader   l'en-tête Authorization de l'appelant, tel quel
 */
export async function doubleFacteurManquant(
  supabaseUrl: string | undefined,
  anonKey: string | undefined,
  authHeader: string | null | undefined,
  fetchFn: typeof fetch = fetch,
): Promise<boolean> {
  if (!supabaseUrl || !anonKey || !authHeader) return true;
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
    if (!res.ok) return true;
    const etat = await res.json();
    if (!etat || typeof etat.exige !== 'boolean') return true;
    return etat.exige && etat.aal !== 'aal2';
  } catch {
    return true;
  }
}
