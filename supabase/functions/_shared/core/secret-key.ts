// Lecture de la cle secrete du projet, sans aucune dependance externe : ce module
// est importe par des fonctions qui n'ont pas besoin du client admin de env.ts,
// et un import de env.ts y instancierait un createClient au demarrage a froid.
//
// La plateforme injecte SUPABASE_SECRET_KEYS, un objet JSON {nom: cle} contenant
// les cles « sb_secret_... ». On lit la cle nommee « default » (la cle
// « poste_accattone_scripts_2026_08 » est reservee aux scripts d'administration
// lances a la main, pour qu'une fuite cote poste de travail n'oblige pas a faire
// tourner celle des Edge Functions).
//
// Les cles legacy (anon + service_role) sont DESACTIVEES depuis le 02/09/2026
// (B18) : le repli sur SUPABASE_SERVICE_ROLE_KEY est retire — une cle morte ne
// merite pas de chemin de code, et un repli vers elle masquerait une panne de
// SUPABASE_SECRET_KEYS au lieu de la dire (DOC-SILENCE-1).
export function secretKey(): string | undefined {
  const brut = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (brut) {
    try {
      const nommees = JSON.parse(brut);
      const cle = nommees?.default;
      if (typeof cle === "string" && cle.length > 0) return cle;
    } catch {
      // JSON illisible : mustSecretKey() levera, bruyamment.
    }
  }
  return undefined;
}

// Pendant « levant » de secretKey(), au contrat identique au mustEnv() que
// quatre fonctions redefinissent localement : leve si la cle est absente,
// renvoie la valeur emondee sinon.
export function mustSecretKey(): string {
  const cle = secretKey();
  if (!cle || !cle.trim()) {
    throw new Error("Missing env: SUPABASE_SECRET_KEYS (cle « default »)");
  }
  return cle.trim();
}
