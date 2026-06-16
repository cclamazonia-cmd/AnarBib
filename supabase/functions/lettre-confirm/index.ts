// supabase/functions/lettre-confirm/index.ts
// EF PUBLIQUE (verify_jwt=false) — confirmation du double opt-in de la Lettre de la
// fédération. 1-clic depuis l'e-mail : valide le token, pose le consentement (RPC
// api.fn_lettre_confirm), rend une page localisée. Aucun login. service_role pour
// lire la locale (bypass RLS). Idempotent (token usage unique côté RPC).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { tMail } from "../_shared/i18n/mail-strings.ts";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const APP_URL = "https://app.anarbib.org";

function page(locale: string, headingKey: string, status = 200): Response {
  const heading = tMail(locale, headingKey);
  const cta = tMail(locale, "lettre.landing.cta");
  const html = `<!DOCTYPE html><html lang="${locale}"><head><meta charset="utf-8">`
    + `<meta name="viewport" content="width=device-width,initial-scale=1"><title>${heading}</title>`
    + `<style>body{font-family:system-ui,-apple-system,sans-serif;max-width:34rem;margin:4rem auto;`
    + `padding:0 1.2rem;color:#1a1a1a;text-align:center;line-height:1.5}`
    + `h1{font-size:1.4rem;color:#cf1f27}`
    + `a{display:inline-block;margin-top:1.6rem;background:#cf1f27;color:#fff;padding:.6rem 1.3rem;`
    + `border-radius:6px;text-decoration:none}</style></head>`
    + `<body><h1>${heading}</h1><a href="${APP_URL}">${cta}</a></body></html>`;
  return new Response(html, { status, headers: { "content-type": "text/html; charset=utf-8" } });
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
  if (!token) return page("pt-BR", "lettre.landing.invalid", 400);
  const locale = await localeForToken(token);
  const { data, error } = await sb.schema("api").rpc("fn_lettre_confirm", { p_token: token });
  if (error) return page(locale, "lettre.landing.error", 500);
  const status = String(data || "");
  if (status === "confirmed") return page(locale, "lettre.landing.confirmed");
  if (status === "already") return page(locale, "lettre.landing.already");
  if (status === "expired") return page(locale, "lettre.landing.expired", 410);
  return page(locale, "lettre.landing.invalid", 400);
});
