// supabase/functions/notify-rede-digest/index.ts
// ============================================================================
// Digest hebdomadaire « actus réseau » par e-mail.
// ----------------------------------------------------------------------------
// Objectif : atteindre le·la lecteur·rice PASSIF·VE (qui ne va pas sur /federacao)
// avec les nouveautés réseau qui, autrement, n'arrivent que via les avis IN-APP
// (Phases 1-3) — la Gazette et les nouveaux cercles. La Lettre, elle, a déjà son
// propre e-mail (fn_lettre_issue_send) : le digest ne la double PAS.
//
// Consentement : ADOSSÉ à la Lettre (profiles.consent_lettre) — pas de nouveau
// opt-in. Désabonnement = celui de la Lettre (token lettre_consent_tokens →
// EF lettre-unsubscribe). 1 e-mail par abonné·e, localisé.
//
// Calibrage : ne part QUE s'il y a du neuf (≥1 Gazette publiée OU ≥1 cercle ouvert
// dans la fenêtre). Déclenché par pg_cron (fn_rede_digest_call → net.http_post),
// authentifié par WEBHOOK_SECRET_NOTIFY_REDE_DIGEST (verify_jwt=false). Envoi Resend.
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { tMail, greeting } from "../_shared/i18n/mail-strings.ts";

const APP_URL = "https://app.anarbib.org";

function mustEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v || !v.trim()) throw new Error(`Missing env: ${name}`);
  return v.trim();
}
function json(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}
function esc(value: unknown): string {
  return String(value ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c] as string));
}
function isValidEmail(email: unknown): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || "").trim());
}
function formatMailAddress(email: string, name?: string | null): string {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}

async function sendViaResend(opts: { senderName: string; senderEmail: string; to: string; subject: string; html: string; text: string }): Promise<void> {
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${resendKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: formatMailAddress(opts.senderEmail, opts.senderName),
      to: [opts.to],
      subject: opts.subject,
      html: opts.html,
      text: opts.text,
    }),
  });
  if (!res.ok) throw new Error(`Resend error HTTP ${res.status}: ${await res.text()}`);
}

function section(headingHtml: string, itemsHtml: string): string {
  return `<h3 style="margin:18px 0 8px 0;font-size:16px;color:#fff;">${headingHtml}</h3>`
    + `<ul style="margin:0 0 6px 0;padding-left:20px;line-height:1.6;color:#f2f2f2;font-size:14px;">${itemsHtml}</ul>`;
}

function renderDigest(opts: {
  brand: string; loc: string; name?: string | null; logoUrl: string; footerText: string;
  unsubUrl: string;
  gazettes: Array<{ number: number; masthead_title?: string | null }>;
  circles: Array<{ name: string; description?: string | null }>;
}): { subject: string; html: string; text: string } {
  const { brand, loc, gazettes, circles, unsubUrl, logoUrl, footerText } = opts;
  const subject = tMail(loc, "rede.digest.subject", { brand });
  const title = tMail(loc, "rede.digest.title");
  const intro = tMail(loc, "rede.digest.intro");
  const greet = greeting(loc, opts.name);
  const unsubLabel = tMail(loc, "rede.digest.unsub");

  let sections = "";
  if (gazettes.length) {
    const items = gazettes.map((g) =>
      `<li><a href="${APP_URL}/federacao/gazeta" style="color:#93c5fd;text-decoration:none;">${esc(g.masthead_title || `Gazette n° ${g.number}`)}</a></li>`
    ).join("");
    sections += section(esc(tMail(loc, "rede.digest.gazette.heading")), items);
  }
  if (circles.length) {
    const items = circles.map((c) =>
      `<li><a href="${APP_URL}/federacao/circulos" style="color:#93c5fd;text-decoration:none;">${esc(c.name)}</a>${c.description ? ` — <span style="color:#d4d4d8;">${esc(c.description)}</span>` : ""}</li>`
    ).join("");
    sections += section(esc(tMail(loc, "rede.digest.circles.heading")), items);
  }

  const logoHtml = logoUrl
    ? `<img src="${esc(logoUrl)}" alt="${esc(brand)}" style="display:block;max-width:96px;max-height:60px;width:auto;height:auto;object-fit:contain;">`
    : `<div style="font-size:20px;font-weight:700;color:#fff;">${esc(brand)}</div>`;

  const html = `<!doctype html><html lang="${esc(loc)}"><head><meta charset="utf-8">`
    + `<meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(subject)}</title></head>`
    + `<body style="margin:0;padding:0;background:#0f0f10;color:#f2f2f2;font-family:Arial,Helvetica,sans-serif;">`
    + `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0f0f10;"><tr><td align="center" style="padding:24px;">`
    + `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:680px;background:#18181b;border:1px solid rgba(255,255,255,0.08);border-radius:16px;overflow:hidden;">`
    + `<tr><td style="padding:22px 24px;background:linear-gradient(135deg,#6f000f 0%,#b30018 45%,#111 100%);">`
    + `<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr>`
    + `<td valign="middle" style="width:120px;">${logoHtml}</td>`
    + `<td valign="middle" style="padding-left:16px;"><h1 style="margin:0;font-size:22px;line-height:1.2;color:#fff;">${esc(title)}</h1></td>`
    + `</tr></table></td></tr>`
    + `<tr><td style="padding:24px;line-height:1.5;">`
    + `<p style="margin:0 0 10px 0;">${esc(greet)}</p>`
    + `<p style="margin:0 0 4px 0;">${esc(intro)}</p>`
    + sections
    + `</td></tr>`
    + `<tr><td style="padding:16px 24px;border-top:1px solid rgba(255,255,255,0.08);font-size:12px;color:#d4d4d8;line-height:1.5;">`
    + `${esc(footerText)}<br><a href="${esc(unsubUrl)}" style="color:#9ca3af;text-decoration:underline;">${esc(unsubLabel)}</a>`
    + `</td></tr></table></td></tr></table></body></html>`;

  const textLines = [title, "", intro, ""];
  if (gazettes.length) {
    textLines.push(tMail(loc, "rede.digest.gazette.heading"));
    for (const g of gazettes) textLines.push(`- ${g.masthead_title || `Gazette n° ${g.number}`} : ${APP_URL}/federacao/gazeta`);
    textLines.push("");
  }
  if (circles.length) {
    textLines.push(tMail(loc, "rede.digest.circles.heading"));
    for (const c of circles) textLines.push(`- ${c.name}${c.description ? ` — ${c.description}` : ""} : ${APP_URL}/federacao/circulos`);
    textLines.push("");
  }
  textLines.push(footerText, `${unsubLabel}: ${unsubUrl}`);

  return { subject, html, text: textLines.join("\n") };
}

Deno.serve(async (req) => {
  const body = await req.json().catch(() => null);
  try {
    if (req.method !== "POST") return json(405, { ok: false, error: "Method not allowed" });
    const expected = mustEnv("WEBHOOK_SECRET_NOTIFY_REDE_DIGEST");
    const got = (req.headers.get("x-webhook-secret") ?? "").trim();
    if (!got || got !== expected) return json(401, { ok: false, error: "Unauthorized" });

    const supabaseUrl = mustEnv("SUPABASE_URL");
    const sb = createClient(supabaseUrl, mustEnv("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });

    // Fenêtre : [since, until). Défaut = 7 derniers jours.
    const until = body?.until ? new Date(body.until) : new Date();
    const since = body?.since ? new Date(body.since) : new Date(until.getTime() - 7 * 24 * 3600 * 1000);
    const sinceISO = since.toISOString();
    const untilISO = until.toISOString();

    // Nouveautés de la fenêtre (la Lettre est exclue : elle a son propre e-mail).
    const { data: gzRaw } = await sb.from("gazette_issues")
      .select("id,number,masthead_title,published_at")
      .eq("status", "published").gte("published_at", sinceISO).lt("published_at", untilISO)
      .order("published_at", { ascending: false });
    const { data: csRaw } = await sb.from("circles")
      .select("id,name,description,created_at,is_open")
      .eq("is_open", true).gte("created_at", sinceISO).lt("created_at", untilISO)
      .order("created_at", { ascending: false });
    const gazettes = gzRaw || [];
    const circles = csRaw || [];

    if (gazettes.length === 0 && circles.length === 0) {
      return json(200, { ok: true, skipped: true, reason: "no new items", since: sinceISO, until: untilISO });
    }

    // Abonné·es = consentement Lettre (réutilisé).
    const { data: subsRaw } = await sb.from("profiles")
      .select("id,email,first_name,preferred_language")
      .eq("consent_lettre", true);
    const recipients = (subsRaw || []).filter((p) => isValidEmail(p.email));
    if (recipients.length === 0) {
      return json(200, { ok: true, sent: 0, reason: "no subscribers", items: { gazette: gazettes.length, circles: circles.length } });
    }

    // Tokens de désabonnement (réutilise lettre_consent_tokens) : récupérer + créer les manquants.
    const ids = recipients.map((r) => r.id);
    const { data: toks } = await sb.from("lettre_consent_tokens")
      .select("user_id,token").eq("action", "unsubscribe").is("consumed_at", null).in("user_id", ids);
    const tokenByUser = new Map<string, string>();
    for (const t of (toks || [])) if (!tokenByUser.has(t.user_id)) tokenByUser.set(t.user_id, t.token);
    const missing = recipients.filter((r) => !tokenByUser.has(r.id)).map((r) => ({ user_id: r.id, action: "unsubscribe" }));
    if (missing.length) {
      const { data: ins } = await sb.from("lettre_consent_tokens").insert(missing).select("user_id,token");
      for (const t of (ins || [])) tokenByUser.set(t.user_id, t.token);
    }

    const brand = (Deno.env.get("NETWORK_BRAND_NAME") || Deno.env.get("BRAND_NAME") || "AnarBib").trim();
    const senderName = (Deno.env.get("SENDER_NAME") || brand).trim();
    const senderEmail = (Deno.env.get("SENDER_EMAIL") || "anarbib@anarbib.org").trim();
    const logoUrl = (Deno.env.get("NETWORK_LOGO_URL") || Deno.env.get("LOGO_URL") || "").trim();
    const footerText = (Deno.env.get("NETWORK_FOOTER_TEXT") || Deno.env.get("FOOTER_TEXT") || "AnarBib — Rede de bibliotecas libertárias.").trim();

    let sent = 0;
    const errors: Array<{ email: string; error: string }> = [];
    for (const r of recipients) {
      const loc = r.preferred_language || "pt-BR";
      const token = tokenByUser.get(r.id) || "";
      const unsubUrl = `${supabaseUrl}/functions/v1/lettre-unsubscribe?token=${encodeURIComponent(token)}`;
      const { subject, html, text } = renderDigest({ brand, loc, name: r.first_name, logoUrl, footerText, unsubUrl, gazettes, circles });
      try {
        await sendViaResend({ senderName, senderEmail, to: r.email, subject, html, text });
        sent++;
      } catch (e) {
        errors.push({ email: r.email, error: String((e as Error)?.message ?? e) });
      }
    }

    return json(200, {
      ok: true, sent, errors_count: errors.length, errors: errors.slice(0, 10),
      items: { gazette: gazettes.length, circles: circles.length },
      since: sinceISO, until: untilISO,
    });
  } catch (error) {
    return json(500, { ok: false, error: String((error as Error)?.message ?? error) });
  }
});
