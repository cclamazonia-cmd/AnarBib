// ═══════════════════════════════════════════════════════════
// AnarBib — B43 (13/10/2026) : « l'appelant administre-t-il le réseau ? »,
// demandé à la base sous le jeton de l'appelant.
//
// Pour les Edge Functions réservées à l'administration du réseau qui
// travaillent ensuite à la clé de service. verify_jwt = true ne suffit pas :
// la clé anon est elle aussi un JWT valide, et n'importe quel lecteur connecté
// en présente un. La règle reste à un seul endroit, la base
// (public.fn_caller_is_network_admin : network_administrators, statut
// 'active').
//
// La requête part sous le jeton de l'appelant, donc la fonction d'avant-requête
// de PostgREST (B42) la refuse aussi pour une session aal1 d'un compte qui doit
// être en aal2 : la double authentification est couverte du même geste.
//
// ÉCHEC FERMÉ : seule la réponse `true` ouvre. Une erreur, un corps inattendu,
// le réseau, un en-tête absent : on refuse.
//
// Sans dépendance à Deno : chargé tel quel par vitest
// (src/tests/probe-partner-catalog-garde.test.js), fetch injectable.
// ═══════════════════════════════════════════════════════════

/**
 * Vrai seulement quand la base répond que l'appelant administre le réseau.
 * @param supabaseUrl  SUPABASE_URL
 * @param anonKey      clé publique (SUPABASE_ANON_KEY)
 * @param authHeader   l'en-tête Authorization de l'appelant, tel quel
 */
export async function appelantAdministreLeReseau(
  supabaseUrl: string | undefined,
  anonKey: string | undefined,
  authHeader: string | null | undefined,
  fetchFn: typeof fetch = fetch,
): Promise<boolean> {
  if (!supabaseUrl || !anonKey || !authHeader) return false;
  if (!/^bearer\s+\S+/i.test(authHeader)) return false;
  try {
    const res = await fetchFn(`${supabaseUrl}/rest/v1/rpc/fn_caller_is_network_admin`, {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: authHeader,
        'Content-Type': 'application/json',
      },
      body: '{}',
    });
    if (!res.ok) return false;
    return (await res.json()) === true;
  } catch {
    return false;
  }
}
