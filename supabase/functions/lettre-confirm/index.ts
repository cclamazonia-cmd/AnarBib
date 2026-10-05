// supabase/functions/lettre-confirm/index.ts
// EF PUBLIQUE (verify_jwt=false) — confirmation du double opt-in de la Lettre de la
// fédération. 1-clic depuis l'e-mail : valide le token, pose le consentement (RPC
// api.fn_lettre_confirm), rend une page localisée. Aucun login. service_role pour
// lire la locale (bypass RLS). Idempotent (token usage unique côté RPC).
import { secretKey } from "../_shared/core/secret-key.ts";
import { createClient } from '../_shared/deps.ts';
import { APP_BASE_URL } from "../_shared/core/app-url.ts";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  secretKey()!,
  { auth: { persistSession: false } },
);

// 05/10/2026 : la plateforme sert les Edge Functions en text/plain (CSP
// « sandbox ») sur son domaine — une page HTML rendue ici s'affichait en code
// source, accents décodés en Latin-1 (« inscriÃ§Ã£o »). La fonction fait son
// travail puis renvoie (303) vers la page /lettre de l'application, qui dit le
// résultat dans la langue de la personne.
function page(locale: string, etat: string, _status = 200): Response {
  const cible = new URL("/lettre", APP_BASE_URL);
  cible.searchParams.set("etat", etat);
  cible.searchParams.set("lang", locale);
  return new Response(null, { status: 303, headers: { Location: cible.toString(), "Cache-Control": "no-store" } });
}

async function localeForToken(token: string): Promise<string> {
  try {
    const { data: tok } = await sb.from("lettre_consent_tokens").select("user_id").eq("token", token).maybeSingle();
    if (!tok?.user_id) return "pt-BR";
    const { data: prof } = await sb.from("profiles").select("preferred_language").eq("id", tok.user_id).maybeSingle();
    return prof?.preferred_language || "pt-BR";
  } catch {
    return "pt-BR";
  }
}

Deno.serve(async (req) => {
  const token = new URL(req.url).searchParams.get("token") || "";
  if (!token) return page("pt-BR", "invalid", 400);
  const locale = await localeForToken(token);
  const { data, error } = await sb.schema("api").rpc("fn_lettre_confirm", { p_token: token });
  if (error) return page(locale, "error", 500);
  const status = String(data || "");
  if (status === "confirmed") return page(locale, "confirmed");
  if (status === "already") return page(locale, "already");
  if (status === "expired") return page(locale, "expired", 410);
  return page(locale, "invalid", 400);
});
