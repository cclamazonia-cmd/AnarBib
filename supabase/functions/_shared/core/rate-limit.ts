// CHEMIN DÉPÔT : supabase/functions/_shared/core/rate-limit.ts
//
// Compteurs d'abus partagés, sur la table public.auth_rate_limits (B25/B26,
// 16/09/2026). Quatre fonctions comptaient chacune à sa façon, par un `hit()`
// copié trois fois qui n'a JAMAIS compté : la contrainte de la table
// (`kind IN ('ip','email')`, socle de mai) refusait leurs `kind`, et personne ne
// lisait `error`. Ici, une seule façon de compter, et trois règles :
//
//   1. La clé est une EMPREINTE (SHA-256 hexadécimal, 64 caractères), jamais
//      l'adresse IP ni le courriel : la table ne sait pas qui, et les journaux
//      edge (où passe la query string d'un DELETE) non plus. La table le garde
//      par contrainte (`auth_rate_limits_key_empreinte`).
//   2. Un compteur qui ne se lit pas ou ne s'écrit pas ne laisse pas passer :
//      `frapper` lève `CompteurIndisponible`, `freiner` répond 500. Un frein
//      qui ne sait pas compter et laisse passer en silence, c'est ce qu'on a
//      eu de juin à septembre.
//   3. Fenêtre fixe : `limite` frappes par `fenetreMin` minutes ; la frappe de
//      trop bloque pour une fenêtre entière, puis le compteur repart de 1.
//      (L'ancien `hit()` ne repartait jamais : une fois la limite atteinte,
//      chaque frappe re-bloquait — bloqué pour toujours.)
//
// Les `kind` autorisés sont ceux de la contrainte `auth_rate_limits_kind_check`
// (migration 20260916201249) : en ajouter un, c'est élargir la contrainte ET la
// suite tests/sql/compteurs_d_abus_tests.sql.

export const EMPREINTE = /^[0-9a-f]{64}$/;

export async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export class CompteurIndisponible extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CompteurIndisponible";
  }
}

export type Verdict = "ok" | "limite";

// Une frappe de plus sur le compteur (kind, empreinte). Renvoie « ok » tant que
// la fenêtre n'a pas reçu plus de `limite` frappes, « limite » sinon (et pose
// blocked_until pour une fenêtre). Lève CompteurIndisponible si la table ne
// répond pas, ou si la clé n'est pas une empreinte.
// deno-lint-ignore no-explicit-any
export async function frapper(sb: any, kind: string, empreinte: string, limite: number, fenetreMin: number): Promise<Verdict> {
  if (!EMPREINTE.test(empreinte)) {
    throw new CompteurIndisponible(`clé non hachée pour le compteur ${kind}`);
  }
  const { data, error } = await sb.from("auth_rate_limits")
    .select("failure_count,first_failure_at,blocked_until")
    .eq("kind", kind).eq("key", empreinte).maybeSingle();
  if (error) {
    throw new CompteurIndisponible(`lecture du compteur ${kind} : ${error.message ?? error.code ?? String(error)}`);
  }
  const now = new Date();
  if (data?.blocked_until && new Date(data.blocked_until) > now) return "limite";

  const fenetreMs = fenetreMin * 60_000;
  const debut = data?.first_failure_at ? new Date(data.first_failure_at).getTime() : NaN;
  const dansLaFenetre = Number.isFinite(debut) && now.getTime() - debut < fenetreMs;
  const count = dansLaFenetre ? Number(data?.failure_count ?? 0) + 1 : 1;
  const depasse = count > limite;

  const { error: errEcriture } = await sb.from("auth_rate_limits").upsert({
    kind,
    key: empreinte,
    failure_count: count,
    first_failure_at: dansLaFenetre ? data.first_failure_at : now.toISOString(),
    last_failure_at: now.toISOString(),
    blocked_until: depasse ? new Date(now.getTime() + fenetreMs).toISOString() : null,
  }, { onConflict: "kind,key" });
  if (errEcriture) {
    throw new CompteurIndisponible(`écriture du compteur ${kind} : ${errEcriture.message ?? errEcriture.code ?? String(errEcriture)}`);
  }
  return depasse ? "limite" : "ok";
}

// Le geste complet d'un handler : rend la réponse à renvoyer (429 si la limite
// est atteinte, 500 si le compteur est indisponible), ou null pour continuer.
// `json` est le constructeur de réponse de la fonction appelante (CORS compris).
// deno-lint-ignore no-explicit-any
export async function freiner(sb: any, kind: string, empreinte: string, limite: number, fenetreMin: number, json: (body: unknown, status: number) => Response): Promise<Response | null> {
  try {
    const v = await frapper(sb, kind, empreinte, limite, fenetreMin);
    return v === "limite" ? json({ error: "rate_limited" }, 429) : null;
  } catch (e) {
    console.error(`compteur ${kind} indisponible —`, (e as Error)?.message ?? e);
    return json({ error: "rate_limit_unavailable" }, 500);
  }
}
