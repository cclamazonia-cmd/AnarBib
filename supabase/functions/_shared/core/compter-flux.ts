// AnarBib — compter les appels aux flux OPDS et RSS (J10 / DOC-GEL-2, 22/10/2026).
//
// Décision de Xavier : ces flux sont gelés en l'état et mesurés un mois avant
// tout travail. Chaque appel servi ajoute un au compteur du jour
// (`private.flux_appels`, via `public.fn_flux_compter_v1`) : le flux, la route,
// et une FAMILLE d'application tirée du User-Agent par la liste fermée
// ci-dessous. Rien d'autre ne sort de la requête : ni adresse IP, ni User-Agent
// complet, ni heure.
//
// Le compteur a son propre client, en clé secrète, qui n'appelle QUE cette
// fonction : le flux OPDS garde sa lecture en clé publique (la RLS reste sa
// garde). Un compteur en panne ne casse jamais un flux : toute erreur est tue.
import { createClient } from "../deps.ts";
import { secretKey } from "./secret-key.ts";

// Ordre = priorité : les applications d'abord, puis les robots, puis les
// navigateurs (dont le User-Agent contient souvent « Mozilla »).
const FAMILLES: [string, RegExp][] = [
  ["koreader", /koreader/i],
  ["calibre", /calibre/i],
  ["thorium", /thorium/i],
  ["foliate", /foliate/i],
  ["moon-reader", /moon\+?\s*reader/i],
  ["aldiko", /aldiko/i],
  ["kybook", /kybook/i],
  ["pocketbook", /pocketbook/i],
  ["librera", /librera/i],
  ["feedly", /feedly/i],
  ["inoreader", /inoreader/i],
  ["newsblur", /newsblur/i],
  ["feedbin", /feedbin/i],
  ["freshrss", /freshrss/i],
  ["tiny-tiny-rss", /tiny\s*tiny\s*rss|tt-rss/i],
  ["miniflux", /miniflux/i],
  ["netnewswire", /netnewswire/i],
  ["thunderbird", /thunderbird/i],
  ["nextcloud-news", /nextcloud.*news/i],
  ["robot", /bot\b|crawl|spider|slurp|curl\/|wget\/|python|go-http|java\/|okhttp|axios|node-fetch|deno\//i],
  ["navigateur", /mozilla|chrome|safari|firefox|edg\//i],
];

export function familleClient(ua: string | null | undefined): string {
  const s = String(ua ?? "").trim();
  if (!s) return "inconnu";
  for (const [nom, re] of FAMILLES) if (re.test(s)) return nom;
  return "autre";
}

export async function compterAppel(flux: "opds" | "rss", route: string, req: Request): Promise<void> {
  try {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const cle = secretKey() ?? "";
    if (!url || !cle) return;
    const db = createClient(url, cle, { auth: { persistSession: false, autoRefreshToken: false } });
    await db.rpc("fn_flux_compter_v1", {
      p_flux: flux,
      p_route: route,
      p_client: familleClient(req.headers.get("user-agent")),
    });
  } catch {
    // un compteur ne casse pas un flux
  }
}
