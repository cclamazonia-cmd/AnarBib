import { secretKey } from "./secret-key.ts";
import { createClient } from "../deps.ts";
export const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
// Nom conserve : 10 fonctions importent ce symbole. Ce n'est plus la cle
// legacy mais la cle secrete nommee « default » (cf. secret-key.ts).
export const SUPABASE_SERVICE_ROLE_KEY = secretKey();
export const WEBHOOK_SECRET = (Deno.env.get("WEBHOOK_SECRET_NOTIFY_EVENT") || "").trim();
// R.7 : variables sender harmonisees sur le couple canonique SENDER_EMAIL /
// SENDER_NAME (les anciens fallbacks ANARBIB_*/NETWORK_*/LIBRARY_* etaient
// alignes sur la meme valeur ; voir investigation digests du 08/06/2026).
export const SENDER_EMAIL = Deno.env.get("SENDER_EMAIL") || "no-reply@example.org";
// F24 (06/10/2026, décision de Xavier) : sans secret SENDER_NAME, les courriels
// partent au nom de « AnarBib » — un nom propre, le même dans toutes les langues
// (« Biblioteca da rede AnarBib » arrivait en portugais dans toutes les boîtes).
export const SENDER_NAME = Deno.env.get("SENDER_NAME") || "AnarBib";
export const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") || Deno.env.get("LIBRARY_ADMIN_EMAIL") || Deno.env.get("ANARBIB_ADMIN_EMAIL") || Deno.env.get("NETWORK_ADMIN_EMAIL") || Deno.env.get("ADMIN_EMAIL_NOTIFY_EVENT") || Deno.env.get("BLMF_ADMIN_EMAIL") || "").trim();
export const ADMIN_NAME = (Deno.env.get("ADMIN_NAME") || Deno.env.get("LIBRARY_ADMIN_NAME") || Deno.env.get("ANARBIB_ADMIN_NAME") || Deno.env.get("NETWORK_ADMIN_NAME") || Deno.env.get("BLMF_ADMIN_NAME") || "").trim();
// LIBRARIAN_PHONE (et ses alias ANARBIB_/NETWORK_) n'est plus lu (16/10/2026) : un
// téléphone GLOBAL s'imprimait dans les courriels de TOUTES les bibliothèques — le
// portable de l'admin de la BLMF chez les lectrices de la BTL. Le téléphone d'un
// courriel est celui de LA bibliothèque (library_public_contact.public_phone, lu
// avec le contexte) ; un courriel du réseau n'en porte pas.
export const BRAND_NAME = Deno.env.get("BRAND_NAME") || Deno.env.get("LIBRARY_BRAND_NAME") || Deno.env.get("ANARBIB_BRAND_NAME") || Deno.env.get("NETWORK_BRAND_NAME") || Deno.env.get("BLMF_BRAND_NAME") || "AnarBib";
export const FOOTER_TEXT = Deno.env.get("FOOTER_TEXT") || Deno.env.get("LIBRARY_FOOTER_TEXT") || Deno.env.get("ANARBIB_FOOTER_TEXT") || Deno.env.get("NETWORK_FOOTER_TEXT") || Deno.env.get("BLMF_FOOTER_TEXT") || null;
export const LOGO_URL = Deno.env.get("LOGO_URL") || Deno.env.get("LIBRARY_LOGO_URL") || Deno.env.get("ANARBIB_LOGO_URL") || Deno.env.get("NETWORK_LOGO_URL") || Deno.env.get("BLMF_LOGO_URL") || "";
// Foyer unique : _shared/core/app-url.ts (module sans effet de bord, importable par
// les fonctions autonomes). Ré-exporté ici pour les neuf modules qui le lisent.
export { APP_BASE_URL } from "./app-url.ts";
export const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    persistSession: false
  }
});
