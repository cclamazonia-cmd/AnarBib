// CHEMIN DÉPÔT : supabase/functions/_shared/core/rate-limit.ts
//
// Compteurs d'abus partagés, sur la table public.auth_rate_limits (B25/B26,
// 16/09/2026). Quatre fonctions comptaient chacune à sa façon, par un `hit()`
// copié trois fois qui n'a JAMAIS compté : la contrainte de la table
// (`kind IN ('ip','email')`, socle de mai) refusait leurs `kind`, et personne ne
// lisait `error`. Ici, une seule façon de compter, et quatre règles :
//
//   1. La clé est une EMPREINTE (64 hexadécimaux), jamais l'adresse IP ni le
//      courriel : la table ne sait pas qui, et les journaux edge (où passe la
//      query string d'un DELETE) non plus. La table le garde par contrainte
//      (`auth_rate_limits_key_empreinte`).
//   2. L'empreinte est un HMAC-SHA256 à clé secrète (`cleDeCompteur`, 19/10/2026),
//      plus un SHA-256 nu : il n'y a que 2^32 adresses IPv4, et un SHA-256 nu
//      se retrouvait en quelques minutes à partir d'une copie de la table ou des
//      colonnes source_ip_hash. Sans le secret, l'empreinte ne dit rien.
//   3. Un compteur qui ne se lit pas ou ne s'écrit pas ne laisse pas passer :
//      `frapper` lève `CompteurIndisponible`, `freiner` répond 500. Un frein
//      qui ne sait pas compter et laisse passer en silence, c'est ce qu'on a
//      eu de juin à septembre.
//   4. Une frappe est UN appel à public.fn_compteur_frapper (19/10/2026) : la
//      base compte et décide dans la même instruction (INSERT … ON CONFLICT … DO
//      UPDATE … RETURNING). Avant, on lisait la ligne puis on la réécrivait :
//      cent requêtes parallèles lisaient toutes le même compte et passaient
//      toutes. Fenêtre fixe : `limite` frappes par `fenetreMin` minutes ; la
//      frappe de trop bloque `blocageMin` minutes (par défaut une fenêtre),
//      puis le compteur repart de 1.
//
// Les `kind` autorisés sont ceux de la contrainte `auth_rate_limits_kind_check`
// (migration 20260916201249) : en ajouter un, c'est élargir la contrainte ET la
// suite tests/sql/compteurs_d_abus_tests.sql.

import { secretKey } from "./secret-key.ts";

export const EMPREINTE = /^[0-9a-f]{64}$/;

const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

// SHA-256 nu : pour l'empreinte d'un JETON aléatoire (rien à deviner), jamais
// pour une clé de compteur — celle-ci passe par cleDeCompteur.
export async function sha256Hex(s: string): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
}

export class CompteurIndisponible extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CompteurIndisponible";
  }
}

// La clé HMAC est DÉRIVÉE de la clé secrète du projet (présente dans toutes les
// fonctions, hébergé comme auto-hébergé), avec une étiquette propre aux
// compteurs : la clé secrète elle-même ne signe rien d'autre ici. Faire tourner
// la clé secrète remet les compteurs à zéro — sans gravité, ils vivent une heure.
const ETIQUETTE = "anarbib/compteurs-d-abus/v1";
let derivee: { secret: string; cle: Promise<CryptoKey> } | null = null;

function cleHmac(secret: string): Promise<CryptoKey> {
  if (derivee?.secret === secret) return derivee.cle;
  const enc = new TextEncoder();
  const cle = (async () => {
    const maitre = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const brute = await crypto.subtle.sign("HMAC", maitre, enc.encode(ETIQUETTE));
    return crypto.subtle.importKey("raw", brute, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  })();
  derivee = { secret, cle };
  return cle;
}

/** L'empreinte d'une IP, d'un courriel ou d'un identifiant pour les compteurs (et source_ip_hash). */
export async function cleDeCompteur(valeur: string): Promise<string> {
  const secret = secretKey()?.trim();
  if (!secret) throw new CompteurIndisponible("clé secrète absente : empreinte de compteur impossible");
  const sig = await crypto.subtle.sign("HMAC", await cleHmac(secret), new TextEncoder().encode(String(valeur)));
  return hex(sig);
}

export type Verdict = "ok" | "limite";

// Une frappe de plus sur le compteur (kind, empreinte). Renvoie « ok » tant que
// la fenêtre n'a pas reçu plus de `limite` frappes, « limite » sinon. Lève
// CompteurIndisponible si la base ne répond pas, ou si la clé n'est pas une
// empreinte.
// deno-lint-ignore no-explicit-any
export async function frapper(sb: any, kind: string, empreinte: string, limite: number, fenetreMin: number, blocageMin?: number): Promise<Verdict> {
  if (!EMPREINTE.test(empreinte)) {
    throw new CompteurIndisponible(`clé non hachée pour le compteur ${kind}`);
  }
  const { data, error } = await sb.rpc("fn_compteur_frapper", {
    p_kind: kind,
    p_key: empreinte,
    p_limite: limite,
    p_fenetre_min: fenetreMin,
    p_blocage_min: blocageMin ?? fenetreMin,
  });
  if (error) {
    throw new CompteurIndisponible(`compteur ${kind} : ${error.message ?? error.code ?? String(error)}`);
  }
  if (typeof data !== "boolean") {
    throw new CompteurIndisponible(`compteur ${kind} : réponse illisible`);
  }
  return data ? "limite" : "ok";
}

// Rend une frappe (un essai réussi ne compte pas contre l'adresse d'où il
// vient). Sans effet sur un compteur bloqué. Lève comme frapper.
// deno-lint-ignore no-explicit-any
export async function rendre(sb: any, kind: string, empreinte: string): Promise<void> {
  if (!EMPREINTE.test(empreinte)) {
    throw new CompteurIndisponible(`clé non hachée pour le compteur ${kind}`);
  }
  const { error } = await sb.rpc("fn_compteur_rendre", { p_kind: kind, p_key: empreinte });
  if (error) {
    throw new CompteurIndisponible(`compteur ${kind} : ${error.message ?? error.code ?? String(error)}`);
  }
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
