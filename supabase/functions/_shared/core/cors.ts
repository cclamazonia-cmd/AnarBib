// ============================================================================
// Origines du front autorisées — pour les fonctions à CORS restreint (20/09/2026)
// ----------------------------------------------------------------------------
// Trente fonctions répondent `Access-Control-Allow-Origin: *`. Trois ne le font
// pas, à dessein — `geocode`, `submit-cartography-entry`,
// `submit-gazette-contribution` : des formulaires publics qui écrivent ou qui
// coûtent, et qu'on ne veut appelables que depuis NOTRE front. Elles portaient
// chacune la constante "https://app.anarbib.org" en dur. Conséquence mesurée le
// 20/09 en câblant les routes de repli : l'application servie depuis
// `app.anarbib.is` charge, se connecte, et ces trois formulaires échouent au
// contrôle d'origine du navigateur. Même défaut sur une pile auto-hébergée, dont
// le front n'est jamais `app.anarbib.org`.
//
// Ici : UNE liste, et la réponse reprend l'origine de la requête si — et
// seulement si — elle est dans la liste. `Vary: Origin` pour les caches.
//
//   · par défaut : le canonique et les deux routes de repli (runbook
//     docs/journal/operations/RUNBOOK_domaines_repli_2026-09-07.md) ;
//   · `APP_ALLOWED_ORIGINS` (liste séparée par des virgules) REMPLACE la liste —
//     c'est ce qu'une pile auto-hébergée pose dans functions.env.
//
// Une origine inconnue ne reçoit pas d'erreur : elle reçoit l'en-tête du
// canonique, que son navigateur refusera. Le CORS n'est pas une authentification
// (curl l'ignore) ; les vraies gardes de ces fonctions sont Altcha et les
// compteurs d'abus. Ceci borne seulement qui peut les appeler DEPUIS UNE PAGE.
//
// Usage — envelopper le gestionnaire, sans toucher à ses `json()` :
//   Deno.serve(async (req) => avecOrigine(req, await traiter(req)));
// ============================================================================

export const ORIGINES_PAR_DEFAUT = [
  "https://app.anarbib.org",
  "https://app.anarbib.is",
  "https://app.anarbib.org.br",
];

export function originesAutorisees(): string[] {
  const brut = (Deno.env.get("APP_ALLOWED_ORIGINS") ?? "").trim();
  if (!brut) return ORIGINES_PAR_DEFAUT;
  const liste = brut.split(",").map((o) => o.trim().replace(/\/+$/, "")).filter(Boolean);
  return liste.length ? liste : ORIGINES_PAR_DEFAUT;
}

// Pose sur une réponse déjà construite l'origine autorisée qui convient à CETTE
// requête. Ne touche à rien d'autre : méthodes et en-têtes autorisés restent ceux
// que la fonction a posés.
export function avecOrigine(req: Request, res: Response): Response {
  const autorisees = originesAutorisees();
  const origine = (req.headers.get("origin") ?? "").replace(/\/+$/, "");
  const retenue = origine && autorisees.includes(origine) ? origine : autorisees[0];
  res.headers.set("Access-Control-Allow-Origin", retenue);
  res.headers.set("Vary", "Origin");
  return res;
}
